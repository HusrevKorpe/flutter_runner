import AppKit
import Observation
import ServiceManagement

/// User preferences shown in the Settings window.
@MainActor
@Observable
final class AppSettings {
    private enum Keys {
        static let theme = "theme"
        static let appearance = "appearance"
        static let panelLogLines = "panelLogLines"
        static let showShortcutHints = "showShortcutHints"
        static let logFontSize = "logFontSize"
    }

    var theme: AppTheme {
        didSet { UserDefaults.standard.set(theme.rawValue, forKey: Keys.theme) }
    }
    var appearance: AppearanceMode {
        didSet {
            UserDefaults.standard.set(appearance.rawValue, forKey: Keys.appearance)
            applyAppearance()
        }
    }
    /// How many recent log lines the menu bar panel previews (0 hides it).
    var panelLogLines: Int {
        didSet { UserDefaults.standard.set(panelLogLines, forKey: Keys.panelLogLines) }
    }
    var showShortcutHints: Bool {
        didSet { UserDefaults.standard.set(showShortcutHints, forKey: Keys.showShortcutHints) }
    }
    var logFontSize: Double {
        didSet { UserDefaults.standard.set(logFontSize, forKey: Keys.logFontSize) }
    }

    /// Mirrors the system login item; only works from the installed .app bundle.
    private(set) var launchAtLogin = SMAppService.mainApp.status == .enabled
    private(set) var launchAtLoginError: String?

    init() {
        let defaults = UserDefaults.standard
        theme = defaults.string(forKey: Keys.theme).flatMap(AppTheme.init) ?? .flutter
        appearance = defaults.string(forKey: Keys.appearance).flatMap(AppearanceMode.init) ?? .system
        panelLogLines = defaults.object(forKey: Keys.panelLogLines) as? Int ?? 4
        showShortcutHints = defaults.object(forKey: Keys.showShortcutHints) as? Bool ?? true
        logFontSize = defaults.object(forKey: Keys.logFontSize) as? Double ?? 11.5
    }

    func applyAppearance() {
        NSApp?.appearance = appearance.nsAppearance
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        launchAtLoginError = nil
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            launchAtLoginError = Bundle.main.bundleURL.pathExtension != "app"
                ? "Yalnızca /Applications'a kurulu uygulamada çalışır."
                : error.localizedDescription
        }
        launchAtLogin = SMAppService.mainApp.status == .enabled
    }
}
