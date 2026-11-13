import Foundation

/// Lists running devices, shut-down iOS simulators and Android emulators,
/// and starts the latter two.
struct DeviceService {
    let flutter: String

    func allDevices() async -> [Device] {
        async let connected = connectedDevices()
        async let simulators = iosSimulators()
        async let emulators = androidEmulators()
        return await connected + simulators + emulators
    }

    func connectedDevices() async -> [Device] {
        let result = await Shell.run("\(flutter) devices --machine")
        guard let items = Self.jsonArray(in: result.output) else { return [] }
        return items.compactMap { item in
            guard let id = item["id"] as? String,
                  let name = item["name"] as? String,
                  (item["isSupported"] as? Bool) ?? true else { return nil }
            let detail = [item["targetPlatform"] as? String, item["sdk"] as? String]
                .compactMap { $0 }
                .filter { !$0.isEmpty }
                .joined(separator: " · ")
            return Device(id: id, name: name, detail: detail, kind: .connected)
        }
    }

    func iosSimulators() async -> [Device] {
        let result = await Shell.run("xcrun simctl list devices available -j")
        guard let data = result.output.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let runtimes = json["devices"] as? [String: [[String: Any]]] else { return [] }

        var devices: [Device] = []
        for (runtime, entries) in runtimes where runtime.contains("iOS") {
            let runtimeName = Self.runtimeName(runtime)
            for entry in entries where (entry["state"] as? String) == "Shutdown" {
                guard let udid = entry["udid"] as? String,
                      let name = entry["name"] as? String else { continue }
                devices.append(Device(id: udid, name: name, detail: runtimeName, kind: .iosSimulator))
            }
        }
        return devices.sorted { ($0.detail, $0.name) > ($1.detail, $1.name) }
    }

    func androidEmulators() async -> [Device] {
        let result = await Shell.run("\(flutter) emulators")
        return result.output
            .split(separator: "\n")
            .compactMap { line -> Device? in
                let parts = line.components(separatedBy: " • ").map { $0.trimmingCharacters(in: .whitespaces) }
                guard parts.count >= 4, parts.last == "android" else { return nil }
                return Device(id: parts[0], name: parts[1], detail: "Android emülatör", kind: .androidEmulator)
            }
    }

    func boot(_ device: Device) async -> ShellResult {
        switch device.kind {
        case .connected:
            return ShellResult(status: 0, output: "", error: "")
        case .iosSimulator:
            let id = Shell.quote(device.id)
            return await Shell.run("xcrun simctl boot \(id); open -a Simulator --args -CurrentDeviceUDID \(id)")
        case .androidEmulator:
            return await Shell.run("\(flutter) emulators --launch \(Shell.quote(device.id))")
        }
    }

    /// `flutter --machine` output can carry plain-text lines before the JSON.
    static func jsonArray(in text: String) -> [[String: Any]]? {
        guard let start = text.firstIndex(of: "["),
              let end = text.lastIndex(of: "]"),
              start < end,
              let data = String(text[start...end]).data(using: .utf8) else { return nil }
        return try? JSONSerialization.jsonObject(with: data) as? [[String: Any]]
    }

    /// `com.apple.CoreSimulator.SimRuntime.iOS-18-0` → `iOS 18.0`.
    private static func runtimeName(_ identifier: String) -> String {
        guard let last = identifier.split(separator: ".").last else { return identifier }
        let parts = last.split(separator: "-")
        guard let platform = parts.first else { return String(last) }
        return "\(platform) " + parts.dropFirst().joined(separator: ".")
    }
}
