import SwiftUI

@main
struct SimulatorLocationSyncApp: App {
    @StateObject private var model = LocationSyncModel()

    var body: some Scene {
        MenuBarExtra {
            MenuBarContent(model: model)
        } label: {
            Image(systemName: model.menuBarIcon)
                .accessibilityLabel("Simulator Location Sync")
        }
        .menuBarExtraStyle(.window)
    }
}

private struct MenuBarContent: View {
    @ObservedObject var model: LocationSyncModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: model.menuBarIcon)
                    .font(.title2)
                    .foregroundStyle(model.statusColor)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Simulator Location Sync")
                        .font(.headline)
                    Text(model.statusText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }

            Divider()

            Toggle("啟用自動同步", isOn: $model.isSyncEnabled)

            Picker("同步頻率", selection: $model.syncInterval) {
                Text("每 5 秒").tag(5.0)
                Text("每 10 秒").tag(10.0)
                Text("每 30 秒").tag(30.0)
                Text("每 1 分鐘").tag(60.0)
                Text("每 5 分鐘").tag(300.0)
            }
            .disabled(!model.isSyncEnabled)

            if let coordinate = model.coordinateText {
                LabeledContent("Mac 位置", value: coordinate)
                    .font(.caption)
            }

            if let lastSyncText = model.lastSyncText {
                LabeledContent("上次同步", value: lastSyncText)
                    .font(.caption)
            }

            HStack {
                Button("立即同步") {
                    model.syncNow()
                }
                .disabled(!model.canSync)

                Spacer()

                if model.isWorking {
                    ProgressView()
                        .controlSize(.small)
                }
            }

            if model.needsLocationPermission {
                Button("開啟定位服務設定…") {
                    model.openLocationSettings()
                }
            }

            Divider()

            HStack {
                Button("重新偵測模擬器") {
                    model.syncNow()
                }
                Spacer()
                Button("結束") {
                    NSApplication.shared.terminate(nil)
                }
                .keyboardShortcut("q")
            }
        }
        .padding(14)
        .frame(width: 340)
    }
}
