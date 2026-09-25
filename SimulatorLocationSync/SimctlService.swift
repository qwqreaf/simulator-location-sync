import CoreLocation
import Foundation

final class SimctlService {
    enum ServiceError: LocalizedError {
        case commandFailed(String)
        case invalidResponse
        case partialFailure(succeeded: Int, messages: [String])

        var errorDescription: String? {
            switch self {
            case .commandFailed(let message):
                return message
            case .invalidResponse:
                return "無法解析 simctl 回傳內容"
            case .partialFailure(let succeeded, let messages):
                return "成功 \(succeeded) 台；\(messages.joined(separator: "、"))"
            }
        }
    }

    private struct DeviceList: Decodable {
        let devices: [String: [Device]]
    }

    private struct Device: Decodable {
        let udid: String
        let name: String
        let state: String
        let isAvailable: Bool?
    }

    func sync(location: CLLocation, completion: @escaping (Result<Int, Error>) -> Void) {
        DispatchQueue.global(qos: .utility).async {
            do {
                let listData = try self.run(arguments: ["simctl", "list", "devices", "booted", "--json"])
                let devices = try self.bootedDevices(from: listData)

                var succeeded = 0
                var failures: [String] = []
                let coordinate = String(
                    format: "%.8f,%.8f",
                    locale: Locale(identifier: "en_US_POSIX"),
                    location.coordinate.latitude,
                    location.coordinate.longitude
                )

                for device in devices {
                    do {
                        _ = try self.run(arguments: ["simctl", "location", device.udid, "set", coordinate])
                        succeeded += 1
                    } catch {
                        failures.append("\(device.name): \(error.localizedDescription)")
                    }
                }

                if failures.isEmpty {
                    completion(.success(succeeded))
                } else {
                    completion(.failure(ServiceError.partialFailure(succeeded: succeeded, messages: failures)))
                }
            } catch {
                completion(.failure(error))
            }
        }
    }

    private func bootedDevices(from data: Data) throws -> [Device] {
        guard let decoded = try? JSONDecoder().decode(DeviceList.self, from: data) else {
            throw ServiceError.invalidResponse
        }
        return decoded.devices.values
            .flatMap { $0 }
            .filter { $0.state == "Booted" && $0.isAvailable != false }
    }

    private func run(arguments: [String]) throws -> Data {
        let process = Process()
        let stdout = Pipe()
        let stderr = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/xcrun")
        process.arguments = arguments
        process.standardOutput = stdout
        process.standardError = stderr

        do {
            try process.run()
        } catch {
            throw ServiceError.commandFailed("無法啟動 xcrun：\(error.localizedDescription)")
        }

        process.waitUntilExit()
        let output = stdout.fileHandleForReading.readDataToEndOfFile()
        let errorData = stderr.fileHandleForReading.readDataToEndOfFile()

        guard process.terminationStatus == 0 else {
            let message = String(data: errorData, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            throw ServiceError.commandFailed(message?.isEmpty == false ? message! : "simctl 執行失敗")
        }
        return output
    }
}
