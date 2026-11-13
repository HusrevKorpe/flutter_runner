import Foundation

enum SessionEvent {
    case log(String, LogLine.Level)
    case appStarting
    case appStarted
    case debugPort(wsUri: String)
    case devTools(URL)
    case restartFinished(fullRestart: Bool, succeeded: Bool, message: String?)
    case exited(status: Int32)
}

/// One `flutter run --machine` process and its JSON-RPC protocol.
///
/// This is the same daemon protocol VS Code and Android Studio use:
/// requests and events are single-line JSON wrapped in `[ ]`.
final class FlutterSession {
    var onEvent: ((SessionEvent) -> Void)?

    private let process: Process
    private let input = Pipe()
    private let output = Pipe()
    private let errorOutput = Pipe()
    private let queue = DispatchQueue(label: "FlutterSession")

    private var outputBuffer = Data()
    private var errorBuffer = Data()
    private var appId: String?
    private var wsUri: String?
    private var nextRequestId = 1
    private var pendingRequests: [Int: (method: String, fullRestart: Bool)] = [:]
    private var devToolsRequested = false

    init(flutter: String, project: URL, deviceId: String, mode: BuildMode) {
        let command = "exec \(flutter) run --machine -d \(Shell.quote(deviceId)) --\(mode.rawValue)"
        process = Shell.makeProcess(command, workingDirectory: project)
        process.standardInput = input
        process.standardOutput = output
        process.standardError = errorOutput
    }

    var isRunning: Bool { process.isRunning }

    func start() throws {
        output.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            self?.queue.async { self?.consume(data, isError: false) }
        }
        errorOutput.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            self?.queue.async { self?.consume(data, isError: true) }
        }
        process.terminationHandler = { [weak self] process in
            self?.output.fileHandleForReading.readabilityHandler = nil
            self?.errorOutput.fileHandleForReading.readabilityHandler = nil
            let status = process.terminationStatus
            // Through the queue so output that is still buffered is emitted first.
            self?.queue.async { self?.emit(.exited(status: status)) }
        }
        try process.run()
    }

    func hotReload() { restart(full: false) }

    func hotRestart() { restart(full: true) }

    /// Asks the app to stop; kills the process if it has not exited in 5 s.
    func stop() {
        queue.async { [self] in
            if let appId {
                send(method: "app.stop", params: ["appId": appId])
            } else {
                process.terminate()
            }
        }
        queue.asyncAfter(deadline: .now() + 5) { [weak self] in
            guard let self, self.process.isRunning else { return }
            self.process.terminate()
        }
    }

    func kill() {
        if process.isRunning { process.terminate() }
    }

    /// Starts (or reuses) the DevTools server; the URL arrives as `.devTools`.
    func openDevTools() {
        queue.async { [self] in
            devToolsRequested = true
            send(method: "devtools.serve", params: [:])
        }
    }

    // MARK: - Protocol

    private func restart(full: Bool) {
        queue.async { [self] in
            guard let appId else { return }
            send(
                method: "app.restart",
                params: ["appId": appId, "fullRestart": full, "pause": false, "reason": "manual"],
                fullRestart: full
            )
        }
    }

    private func send(method: String, params: [String: Any], fullRestart: Bool = false) {
        let id = nextRequestId
        nextRequestId += 1
        pendingRequests[id] = (method, fullRestart)
        let request: [String: Any] = ["id": id, "method": method, "params": params]
        guard let data = try? JSONSerialization.data(withJSONObject: [request]) else { return }
        input.fileHandleForWriting.write(data + Data("\n".utf8))
    }

    private func consume(_ data: Data, isError: Bool) {
        guard !data.isEmpty else { return }
        if isError {
            errorBuffer.append(data)
            drainLines(from: &errorBuffer) { emit(.log($0, .error)) }
        } else {
            outputBuffer.append(data)
            drainLines(from: &outputBuffer, handle: handleOutputLine)
        }
    }

    private func drainLines(from buffer: inout Data, handle: (String) -> Void) {
        while let newline = buffer.firstIndex(of: UInt8(ascii: "\n")) {
            let lineData = buffer[buffer.startIndex..<newline]
            buffer.removeSubrange(buffer.startIndex...newline)
            let line = String(decoding: lineData, as: UTF8.self)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if !line.isEmpty { handle(line) }
        }
    }

    private func handleOutputLine(_ line: String) {
        guard line.hasPrefix("[{"), line.hasSuffix("}]"),
              let data = line.data(using: .utf8),
              let messages = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            emit(.log(line, .info))
            return
        }
        messages.forEach(handleMessage)
    }

    private func handleMessage(_ message: [String: Any]) {
        if let event = message["event"] as? String {
            handleEvent(event, params: message["params"] as? [String: Any] ?? [:])
        } else if let id = message["id"] as? Int, let request = pendingRequests.removeValue(forKey: id) {
            handleResponse(request, result: message["result"], error: message["error"])
        }
    }

    private func handleEvent(_ event: String, params: [String: Any]) {
        switch event {
        case "app.start":
            appId = params["appId"] as? String
            emit(.appStarting)
        case "app.started":
            emit(.appStarted)
        case "app.log":
            guard let text = params["log"] as? String else { return }
            emit(.log(text, (params["error"] as? Bool) == true ? .error : .info))
        case "app.progress":
            if let text = params["message"] as? String, !text.isEmpty {
                emit(.log(text, .progress))
            }
        case "app.debugPort":
            if let uri = params["wsUri"] as? String {
                wsUri = uri
                emit(.debugPort(wsUri: uri))
            }
        case "daemon.logMessage":
            if let text = params["message"] as? String {
                emit(.log(text, (params["level"] as? String) == "error" ? .error : .system))
            }
        case "app.stop":
            if let error = params["error"] as? String { emit(.log(error, .error)) }
        default:
            break
        }
    }

    private func handleResponse(_ request: (method: String, fullRestart: Bool), result: Any?, error: Any?) {
        switch request.method {
        case "app.restart":
            let payload = result as? [String: Any]
            let code = payload?["code"] as? Int ?? (error == nil ? 0 : 1)
            let message = payload?["message"] as? String ?? (error.map { "\($0)" })
            emit(.restartFinished(fullRestart: request.fullRestart, succeeded: code == 0, message: message))
        case "devtools.serve":
            guard devToolsRequested,
                  let payload = result as? [String: Any],
                  let host = payload["host"] as? String,
                  let port = payload["port"] as? Int else {
                emit(.log("DevTools başlatılamadı: \(error.map { "\($0)" } ?? "bilinmeyen hata")", .error))
                return
            }
            devToolsRequested = false
            var components = URLComponents()
            components.scheme = "http"
            components.host = host
            components.port = port
            if let wsUri { components.queryItems = [URLQueryItem(name: "uri", value: wsUri)] }
            if let url = components.url { emit(.devTools(url)) }
        default:
            if let error { emit(.log("\(request.method): \(error)", .error)) }
        }
    }

    private func emit(_ event: SessionEvent) {
        DispatchQueue.main.async { [weak self] in self?.onEvent?(event) }
    }
}
