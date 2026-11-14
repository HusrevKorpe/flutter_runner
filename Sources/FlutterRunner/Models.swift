import Foundation

enum BuildMode: String, CaseIterable, Identifiable {
    case debug, profile, release

    var id: String { rawValue }
    var title: String { rawValue.capitalized }
    var supportsHotReload: Bool { self == .debug }
}

enum RunStatus: Equatable {
    case idle
    case launching
    case running
    case reloading
    case restarting
    case stopping

    var isActive: Bool { self != .idle }

    var title: String {
        switch self {
        case .idle: "Hazır"
        case .launching: "Başlatılıyor…"
        case .running: "Çalışıyor"
        case .reloading: "Hot reload…"
        case .restarting: "Restart…"
        case .stopping: "Durduruluyor…"
        }
    }
}

struct Device: Identifiable, Hashable {
    enum Kind: Hashable {
        /// Already running and visible to `flutter devices`.
        case connected
        /// A shut-down iOS simulator that has to boot first.
        case iosSimulator
        /// An Android emulator (AVD) that has to launch first.
        case androidEmulator
    }

    let id: String
    let name: String
    let detail: String
    let kind: Kind

    var isReady: Bool { kind == .connected }

    /// Short platform label, e.g. "iOS", "Android", "iOS 18.2".
    var platform: String {
        switch kind {
        case .iosSimulator: return detail
        case .androidEmulator: return "Android"
        case .connected:
            let target = detail.split(separator: "·").first.map { $0.trimmingCharacters(in: .whitespaces) } ?? ""
            if target.hasPrefix("ios") { return "iOS" }
            if target.hasPrefix("android") { return "Android" }
            if target.hasPrefix("darwin") { return "macOS" }
            if target.hasPrefix("web") { return "Web" }
            return target
        }
    }

    var symbol: String {
        switch platform {
        case "Android": "candybarphone"
        case "macOS": "macbook"
        case "Web": "globe"
        default: "iphone"
        }
    }
}

struct LogLine: Identifiable {
    enum Level {
        case info, progress, error, system
    }

    let id: Int
    let text: String
    let level: Level
}
