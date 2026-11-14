import AppKit
import SwiftUI

/// Lives in the menu bar (no Dock icon). The log window opens on demand.
@main
struct FlutterRunnerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    private var menuBarSymbol: String {
        let viewModel = appDelegate.viewModel
        if !viewModel.status.isActive, !viewModel.isBooting, appDelegate.updater.availableVersion != nil {
            return "arrow.down.circle"
        }
        return viewModel.menuBarSymbol
    }

    var body: some Scene {
        MenuBarExtra {
            MenuBarPanel(viewModel: appDelegate.viewModel, updater: appDelegate.updater)
                .environment(appDelegate.settings)
                .tint(appDelegate.settings.theme.accent)
        } label: {
            Image(systemName: menuBarSymbol)
        }
        .menuBarExtraStyle(.window)

        Window("Flutter Runner", id: "main") {
            ContentView(viewModel: appDelegate.viewModel)
                .environment(appDelegate.settings)
                .tint(appDelegate.settings.theme.accent)
        }
        .windowResizability(.contentMinSize)
        .windowToolbarStyle(.unifiedCompact)
        .defaultSize(width: 820, height: 560)
        .defaultLaunchBehavior(.suppressed)

        Settings {
            SettingsView(settings: appDelegate.settings, updater: appDelegate.updater)
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let viewModel = RunnerViewModel()
    let updater = Updater()
    let settings = AppSettings()

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Info.plist sets LSUIElement; this covers `swift run` (no app bundle).
        NSApp.setActivationPolicy(.accessory)
        settings.applyAppearance()

        let viewModel = viewModel
        GlobalHotKeys.shared.onAction = { action in
            switch action {
            case .run: viewModel.runOrBoot()
            case .hotReload: viewModel.hotReload()
            case .hotRestart: viewModel.hotRestart()
            case .stop: viewModel.stop()
            }
        }
        GlobalHotKeys.shared.install()
        Task { await viewModel.refreshDevices() }
        if updater.canUpdate { updater.startPeriodicChecks() }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

    func applicationWillTerminate(_ notification: Notification) {
        viewModel.shutdown()
    }
}

/// Sets the hosting window's level for the "always on top" toggle.
struct WindowAccessor: NSViewRepresentable {
    let alwaysOnTop: Bool

    func makeNSView(context: Context) -> NSView { NSView() }

    func updateNSView(_ view: NSView, context: Context) {
        DispatchQueue.main.async {
            guard let window = view.window else { return }
            window.level = alwaysOnTop ? .floating : .normal
            window.collectionBehavior.insert(.fullScreenAuxiliary)
        }
    }
}
