import AppKit
import CoreLocation
import SwiftUI

@MainActor
final class LocationSyncModel: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var isSyncEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isSyncEnabled, forKey: Keys.isSyncEnabled)
            configureTimer()
        }
    }

    @Published var syncInterval: Double {
        didSet {
            UserDefaults.standard.set(syncInterval, forKey: Keys.syncInterval)
            configureTimer()
        }
    }

    @Published private(set) var statusText = "正在取得 Mac 位置…"
    @Published private(set) var lastLocation: CLLocation?
    @Published private(set) var lastSyncDate: Date?
    @Published private(set) var syncedSimulatorCount = 0
    @Published private(set) var isWorking = false
    @Published private(set) var authorizationStatus: CLAuthorizationStatus = .notDetermined

    private let locationManager = CLLocationManager()
    private let simctl = SimctlService()
    private var timer: Timer?

    private enum Keys {
        static let isSyncEnabled = "isSyncEnabled"
        static let syncInterval = "syncInterval"
    }

    override init() {
        let defaults = UserDefaults.standard
        if defaults.object(forKey: Keys.isSyncEnabled) == nil {
            isSyncEnabled = true
        } else {
            isSyncEnabled = defaults.bool(forKey: Keys.isSyncEnabled)
        }
        let savedInterval = defaults.double(forKey: Keys.syncInterval)
        syncInterval = savedInterval > 0 ? savedInterval : 10

        super.init()

        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = kCLDistanceFilterNone
        authorizationStatus = locationManager.authorizationStatus
        requestLocationAccessIfNeeded()
        configureTimer()
    }

    var canSync: Bool {
        lastLocation != nil && !isWorking && isAuthorized
    }

    var needsLocationPermission: Bool {
        authorizationStatus == .denied || authorizationStatus == .restricted
    }

    var coordinateText: String? {
        guard let coordinate = lastLocation?.coordinate else { return nil }
        return String(format: "%.6f, %.6f", coordinate.latitude, coordinate.longitude)
    }

    var lastSyncText: String? {
        guard let lastSyncDate else { return nil }
        return lastSyncDate.formatted(date: .omitted, time: .standard)
            + "（\(syncedSimulatorCount) 台）"
    }

    var menuBarIcon: String {
        if needsLocationPermission { return "location.slash.fill" }
        if isWorking { return "location.fill.viewfinder" }
        return isSyncEnabled ? "location.fill" : "location"
    }

    var statusColor: Color {
        if needsLocationPermission { return .red }
        if statusText.contains("失敗") || statusText.contains("找不到") { return .orange }
        return isSyncEnabled ? .green : .secondary
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
        switch authorizationStatus {
        case .authorized, .authorizedAlways:
            statusText = "定位已啟用，等待同步"
            manager.startUpdatingLocation()
        case .notDetermined:
            statusText = "等待定位權限…"
        case .denied, .restricted:
            statusText = "需要允許定位權限"
            manager.stopUpdatingLocation()
        @unknown default:
            statusText = "無法判斷定位權限"
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last, location.horizontalAccuracy >= 0 else { return }
        lastLocation = location

        if lastSyncDate == nil && isSyncEnabled {
            syncNow()
        } else if !isWorking {
            statusText = isSyncEnabled ? "定位已更新，等待下次同步" : "自動同步已暫停"
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        if let locationError = error as? CLError, locationError.code == .locationUnknown {
            statusText = "暫時無法取得位置，稍後重試"
        } else {
            statusText = "定位失敗：\(error.localizedDescription)"
        }
    }

    func syncNow() {
        guard !isWorking else { return }
        guard isAuthorized else {
            requestLocationAccessIfNeeded()
            statusText = "需要允許定位權限"
            return
        }
        guard let location = lastLocation else {
            statusText = "尚未取得 Mac 位置"
            locationManager.requestLocation()
            return
        }

        isWorking = true
        statusText = "正在同步到已啟動的模擬器…"
        simctl.sync(location: location) { [weak self] result in
            Task { @MainActor in
                guard let self else { return }
                self.isWorking = false
                switch result {
                case .success(let count):
                    self.syncedSimulatorCount = count
                    self.lastSyncDate = Date()
                    self.statusText = count == 0
                        ? "找不到已啟動的模擬器"
                        : "已同步到 \(count) 台模擬器"
                case .failure(let error):
                    self.statusText = "同步失敗：\(error.localizedDescription)"
                }
            }
        }
    }

    func openLocationSettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_LocationServices") else { return }
        NSWorkspace.shared.open(url)
    }

    private var isAuthorized: Bool {
        authorizationStatus == .authorized || authorizationStatus == .authorizedAlways
    }

    private func requestLocationAccessIfNeeded() {
        switch locationManager.authorizationStatus {
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
        case .authorized, .authorizedAlways:
            locationManager.startUpdatingLocation()
        case .denied, .restricted:
            statusText = "需要允許定位權限"
        @unknown default:
            break
        }
    }

    private func configureTimer() {
        timer?.invalidate()
        timer = nil

        guard isSyncEnabled else {
            if !isWorking { statusText = "自動同步已暫停" }
            return
        }

        timer = Timer.scheduledTimer(withTimeInterval: syncInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.syncNow()
            }
        }
    }
}
