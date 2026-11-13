import AppKit
import SwiftUI

@main
struct FlutterRunnerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var viewModel = RunnerViewModel()

    var body: some Scene {
        Window("Flutter Runner", id: "main") {
            ContentView(viewModel: viewModel)
                .onAppear {
                    appDelegate.viewModel = viewModel
                    GlobalHotKeys.shared.onAction = { action in
                        switch action {
                        case .run: viewModel.runOrBoot()
                        case .hotReload: viewModel.hotReload()
                        case .hotRestart: viewModel.hotRestart()
                        case .stop: viewModel.stop()
                        }
                    }
                    GlobalHotKeys.shared.install()
                }
        }
        .windowResizability(.contentMinSize)
        .defaultSize(width: 760, height: 460)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    weak var viewModel: RunnerViewModel?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Needed when started with `swift run` (no app bundle).
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }

    func applicationWillTerminate(_ notification: Notification) {
        MainActor.assumeIsolated { viewModel?.shutdown() }
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
