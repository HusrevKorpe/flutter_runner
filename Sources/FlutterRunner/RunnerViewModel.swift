import AppKit
import Foundation
import Observation

@MainActor
@Observable
final class RunnerViewModel {
    private enum Keys {
        static let projectPath = "projectPath"
        static let deviceId = "deviceId"
        static let mode = "mode"
        static let alwaysOnTop = "alwaysOnTop"
        static let showLogs = "showLogs"
    }

    private static let maxLogLines = 3000

    var projectURL: URL? {
        didSet { UserDefaults.standard.set(projectURL?.path, forKey: Keys.projectPath) }
    }
    var devices: [Device] = []
    var selectedDeviceId: String? {
        didSet { UserDefaults.standard.set(selectedDeviceId, forKey: Keys.deviceId) }
    }
    var mode: BuildMode {
        didSet { UserDefaults.standard.set(mode.rawValue, forKey: Keys.mode) }
    }
    var alwaysOnTop: Bool {
        didSet { UserDefaults.standard.set(alwaysOnTop, forKey: Keys.alwaysOnTop) }
    }
    var showLogs: Bool {
        didSet { UserDefaults.standard.set(showLogs, forKey: Keys.showLogs) }
    }
    var status: RunStatus = .idle
    var isLoadingDevices = false
    var isBooting = false
    var lastResult: String?
    var logs: [LogLine] = []

    private var session: FlutterSession?
    private var nextLogId = 0
    private var reloadStartedAt: Date?

    init() {
        let defaults = UserDefaults.standard
        projectURL = defaults.string(forKey: Keys.projectPath).map { URL(fileURLWithPath: $0) }
        selectedDeviceId = defaults.string(forKey: Keys.deviceId)
        mode = defaults.string(forKey: Keys.mode).flatMap(BuildMode.init) ?? .debug
        alwaysOnTop = defaults.object(forKey: Keys.alwaysOnTop) as? Bool ?? true
        showLogs = defaults.object(forKey: Keys.showLogs) as? Bool ?? true
    }

    // MARK: - Derived state

    var projectName: String { projectURL?.lastPathComponent ?? "Proje seç" }
    var selectedDevice: Device? { devices.first { $0.id == selectedDeviceId } }
    var canRun: Bool { projectURL != nil && selectedDevice != nil && !status.isActive && !isBooting }
    var canReload: Bool { status == .running && mode.supportsHotReload }
    var canStop: Bool { status.isActive && status != .stopping }
    var canOpenDevTools: Bool { status == .running || status == .reloading || status == .restarting }

    /// SF Symbol for the menu bar icon; reflects the run state at a glance.
    var menuBarSymbol: String {
        if isBooting { return "hourglass" }
        switch status {
        case .idle: return "play.circle"
        case .launching, .stopping: return "hourglass"
        case .running: return "bolt.circle.fill"
        case .reloading, .restarting: return "bolt.circle"
        }
    }

    private var flutter: String { FlutterSdk.command(for: projectURL) }

    // MARK: - Project & devices

    func chooseProject() {
        NSApp.activate(ignoringOtherApps: true)
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.prompt = "Seç"
        panel.message = "pubspec.yaml dosyasının olduğu Flutter proje klasörünü seç"
        panel.directoryURL = projectURL?.deletingLastPathComponent()
        guard panel.runModal() == .OK, let url = panel.url else { return }

        guard FileManager.default.fileExists(atPath: url.appendingPathComponent("pubspec.yaml").path) else {
            appendLog("Bu klasörde pubspec.yaml yok: \(url.path)", .error)
            return
        }
        projectURL = url
        Task { await refreshDevices() }
    }

    func refreshDevices() async {
        guard !isLoadingDevices else { return }
        isLoadingDevices = true
        devices = await DeviceService(flutter: flutter).allDevices()
        isLoadingDevices = false
        if selectedDevice == nil {
            selectedDeviceId = devices.first { $0.isReady }?.id ?? devices.first?.id
        }
    }

    /// Boots a shut-down simulator or emulator and selects it once flutter sees it.
    func bootSelectedDevice() async {
        guard let device = selectedDevice, !device.isReady else { return }
        isBooting = true
        defer { isBooting = false }
        appendLog("\(device.name) açılıyor…", .system)

        let service = DeviceService(flutter: flutter)
        let before = Set(await service.connectedDevices().map(\.id))
        let result = await service.boot(device)
        if !result.succeeded, !result.error.isEmpty {
            appendLog(result.error.trimmingCharacters(in: .whitespacesAndNewlines), .error)
        }

        for _ in 0..<20 {
            try? await Task.sleep(for: .seconds(3))
            let connected = await service.connectedDevices()
            let match = connected.first { $0.id == device.id }
                ?? connected.first { !before.contains($0.id) }
            if let match {
                await refreshDevices()
                selectedDeviceId = match.id
                appendLog("\(match.name) hazır.", .system)
                return
            }
        }
        appendLog("\(device.name) bir dakika içinde hazır olmadı. Yenile'ye basıp tekrar dene.", .error)
    }

    // MARK: - Run controls

    func run() {
        guard canRun, let projectURL, let device = selectedDevice, device.isReady else { return }
        lastResult = nil
        status = .launching
        appendLog("▶ flutter run -d \(device.name) --\(mode.rawValue)", .system)

        let session = FlutterSession(flutter: flutter, project: projectURL, deviceId: device.id, mode: mode)
        session.onEvent = { [weak self] event in self?.handle(event) }
        do {
            try session.start()
            self.session = session
        } catch {
            status = .idle
            appendLog("Başlatılamadı: \(error.localizedDescription)", .error)
        }
    }

    func runOrBoot() {
        if let device = selectedDevice, !device.isReady {
            Task { await bootThenRun() }
        } else {
            run()
        }
    }

    func hotReload() {
        guard canReload else { return }
        status = .reloading
        reloadStartedAt = Date()
        session?.hotReload()
    }

    func hotRestart() {
        guard canReload else { return }
        status = .restarting
        reloadStartedAt = Date()
        session?.hotRestart()
    }

    func stop() {
        guard canStop else { return }
        status = .stopping
        session?.stop()
    }

    func openDevTools() {
        session?.openDevTools()
    }

    func clearLogs() {
        logs.removeAll()
    }

    func shutdown() {
        session?.kill()
    }

    private func bootThenRun() async {
        await bootSelectedDevice()
        if selectedDevice?.isReady == true { run() }
    }

    // MARK: - Session events

    private func handle(_ event: SessionEvent) {
        switch event {
        case let .log(text, level):
            appendLog(text, level)
        case .appStarting:
            status = .launching
        case .appStarted:
            status = .running
            lastResult = "Başladı"
        case .debugPort:
            break
        case let .devTools(url):
            NSWorkspace.shared.open(url)
        case let .restartFinished(fullRestart, succeeded, message):
            status = .running
            let elapsed = reloadStartedAt.map { Int(Date().timeIntervalSince($0) * 1000) }
            let name = fullRestart ? "Restart" : "Hot reload"
            if succeeded {
                lastResult = "\(name) · \(elapsed.map { "\($0) ms" } ?? "tamam")"
            } else {
                lastResult = "\(name) başarısız"
                appendLog(message ?? "\(name) başarısız", .error)
            }
        case let .exited(code):
            session = nil
            status = .idle
            appendLog("⏹ Durdu (çıkış kodu \(code))", code == 0 ? .system : .error)
            lastResult = code == 0 ? "Durduruldu" : "Hata ile kapandı"
        }
    }

    private func appendLog(_ text: String, _ level: LogLine.Level) {
        for line in text.split(separator: "\n", omittingEmptySubsequences: false) {
            logs.append(LogLine(id: nextLogId, text: String(line), level: level))
            nextLogId += 1
        }
        if logs.count > Self.maxLogLines {
            logs.removeFirst(logs.count - Self.maxLogLines)
        }
    }
}
