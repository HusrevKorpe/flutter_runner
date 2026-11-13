import Foundation

struct ShellResult {
    let status: Int32
    let output: String
    let error: String

    var succeeded: Bool { status == 0 }
}

/// Runs commands through zsh with the user's interactive PATH.
///
/// Apps launched from Finder get a minimal PATH, so `flutter`, `fvm` and
/// `xcrun` might not be found. The PATH from an interactive login shell is
/// read once and reused for every command.
enum Shell {
    private static let lock = NSLock()
    private static var cachedPath: String?

    static func quote(_ value: String) -> String {
        "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    static func userPath() -> String {
        lock.lock()
        defer { lock.unlock() }
        if let cachedPath { return cachedPath }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-i", "-l", "-c", "print -rn -- \"__PATH__${PATH}__END__\""]
        process.standardInput = FileHandle.nullDevice
        let output = Pipe()
        process.standardOutput = output
        process.standardError = FileHandle.nullDevice

        var resolved = ProcessInfo.processInfo.environment["PATH"] ?? "/usr/bin:/bin"
        if (try? process.run()) != nil {
            let data = output.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()
            let text = String(decoding: data, as: UTF8.self)
            if let start = text.range(of: "__PATH__"),
               let end = text.range(of: "__END__", range: start.upperBound..<text.endIndex) {
                resolved = String(text[start.upperBound..<end.lowerBound])
            }
        }
        resolved += ":/opt/homebrew/bin:/usr/local/bin:\(NSHomeDirectory())/.pub-cache/bin"
        cachedPath = resolved
        return resolved
    }

    static func makeProcess(_ command: String, workingDirectory: URL? = nil) -> Process {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-c", command]
        if let workingDirectory { process.currentDirectoryURL = workingDirectory }
        var environment = ProcessInfo.processInfo.environment
        environment["PATH"] = userPath()
        environment["TERM"] = "dumb"
        environment["NO_COLOR"] = "1"
        process.environment = environment
        return process
    }

    static func run(_ command: String, workingDirectory: URL? = nil) async -> ShellResult {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                continuation.resume(returning: runBlocking(command, workingDirectory: workingDirectory))
            }
        }
    }

    private static func runBlocking(_ command: String, workingDirectory: URL?) -> ShellResult {
        let process = makeProcess(command, workingDirectory: workingDirectory)
        let output = Pipe()
        let error = Pipe()
        process.standardOutput = output
        process.standardError = error
        process.standardInput = FileHandle.nullDevice

        do {
            try process.run()
        } catch {
            return ShellResult(status: -1, output: "", error: error.localizedDescription)
        }

        // Drain stderr on another thread so a full pipe can never block the process.
        var errorData = Data()
        let group = DispatchGroup()
        group.enter()
        DispatchQueue.global().async {
            errorData = error.fileHandleForReading.readDataToEndOfFile()
            group.leave()
        }
        let outputData = output.fileHandleForReading.readDataToEndOfFile()
        group.wait()
        process.waitUntilExit()

        return ShellResult(
            status: process.terminationStatus,
            output: String(decoding: outputData, as: UTF8.self),
            error: String(decoding: errorData, as: UTF8.self)
        )
    }
}
