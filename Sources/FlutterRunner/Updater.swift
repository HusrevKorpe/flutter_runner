import AppKit
import Foundation
import Observation

/// Checks GitHub Releases for a newer version and replaces the installed app.
///
/// A release needs a `vX.Y.Z` tag and a `FlutterRunner.zip` asset
/// (`scripts/release.sh` creates both). Files downloaded with URLSession get
/// no quarantine flag, so the ad-hoc signed app opens without a Gatekeeper prompt.
@MainActor
@Observable
final class Updater {
    enum State: Equatable {
        case idle
        case checking
        case upToDate
        case available(version: String, notes: String)
        case installing
        case failed(String)
    }

    static let repository = "HusrevKorpe/flutter_runner"
    private static let assetName = "FlutterRunner.zip"
    private static let checkInterval: TimeInterval = 6 * 60 * 60

    private(set) var state: State = .idle
    private var downloadURL: URL?
    private var timer: Timer?

    var currentVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.0.0"
    }

    /// Updating only works for an installed `.app`, not for `swift run`.
    var canUpdate: Bool { Bundle.main.bundleURL.pathExtension == "app" }

    var availableVersion: String? {
        if case let .available(version, _) = state { return version }
        return nil
    }

    func startPeriodicChecks() {
        Task { await check(userInitiated: false) }
        timer = Timer.scheduledTimer(withTimeInterval: Self.checkInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in await self?.check(userInitiated: false) }
        }
    }

    func check(userInitiated: Bool) async {
        guard state != .checking, state != .installing else { return }
        state = .checking
        do {
            let release = try await Self.latestRelease()
            let version = release.tag.trimmingCharacters(in: CharacterSet(charactersIn: "vV"))
            if Self.isVersion(version, newerThan: currentVersion), let asset = release.asset {
                downloadURL = asset
                state = .available(version: version, notes: release.notes)
            } else {
                // Only confirm "up to date" when the user asked; stay quiet otherwise.
                state = userInitiated ? .upToDate : .idle
            }
        } catch {
            // Background checks fail quietly (offline, rate limit); manual ones report.
            state = userInitiated ? .failed(error.localizedDescription) : .idle
        }
    }

    /// Downloads the new app, swaps it in after this process quits, relaunches.
    func install() async {
        guard canUpdate, let downloadURL else { return }
        state = .installing
        do {
            let workDir = FileManager.default.temporaryDirectory
                .appendingPathComponent("FlutterRunnerUpdate-\(UUID().uuidString)")
            try FileManager.default.createDirectory(at: workDir, withIntermediateDirectories: true)

            let (zipFile, response) = try await URLSession.shared.download(from: downloadURL)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else {
                throw UpdateError.message("İndirme başarısız oldu.")
            }
            let zipPath = workDir.appendingPathComponent(Self.assetName)
            try FileManager.default.moveItem(at: zipFile, to: zipPath)

            let unzip = await Shell.run("ditto -x -k \(Shell.quote(zipPath.path)) \(Shell.quote(workDir.path))")
            let newApp = workDir.appendingPathComponent("FlutterRunner.app")
            guard unzip.succeeded, FileManager.default.fileExists(atPath: newApp.path) else {
                throw UpdateError.message("İndirilen dosya açılamadı.")
            }

            try launchSwapScript(newApp: newApp, workDir: workDir)
            NSApp.terminate(nil)
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    /// A detached shell waits for this process to exit, replaces the bundle and reopens it.
    private func launchSwapScript(newApp: URL, workDir: URL) throws {
        let target = Shell.quote(Bundle.main.bundleURL.path)
        let script = """
        while kill -0 \(ProcessInfo.processInfo.processIdentifier) 2>/dev/null; do sleep 0.2; done
        rm -rf \(target) && ditto \(Shell.quote(newApp.path)) \(target)
        xattr -dr com.apple.quarantine \(target) 2>/dev/null
        open \(target)
        rm -rf \(Shell.quote(workDir.path))
        """
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        process.arguments = ["-c", script]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try process.run()
    }

    // MARK: - GitHub

    private struct Release {
        let tag: String
        let notes: String
        let asset: URL?
    }

    private enum UpdateError: LocalizedError {
        case message(String)
        var errorDescription: String? {
            if case let .message(text) = self { return text }
            return nil
        }
    }

    private static func latestRelease() async throws -> Release {
        var request = URLRequest(url: URL(string: "https://api.github.com/repos/\(repository)/releases/latest")!)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("FlutterRunner", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 15

        let (data, response) = try await URLSession.shared.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard status == 200 else {
            throw UpdateError.message(status == 404 ? "Yayınlanmış sürüm bulunamadı." : "GitHub yanıt vermedi (\(status)).")
        }
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let tag = json["tag_name"] as? String else {
            throw UpdateError.message("Sürüm bilgisi okunamadı.")
        }
        let assets = json["assets"] as? [[String: Any]] ?? []
        let asset = assets
            .first { ($0["name"] as? String) == assetName }
            .flatMap { $0["browser_download_url"] as? String }
            .flatMap(URL.init(string:))
        return Release(tag: tag, notes: json["body"] as? String ?? "", asset: asset)
    }

    /// Numeric comparison of dotted versions: 0.10.0 > 0.9.3.
    static func isVersion(_ candidate: String, newerThan current: String) -> Bool {
        let lhs = candidate.split(separator: ".").map { Int($0) ?? 0 }
        let rhs = current.split(separator: ".").map { Int($0) ?? 0 }
        for index in 0..<max(lhs.count, rhs.count) {
            let left = index < lhs.count ? lhs[index] : 0
            let right = index < rhs.count ? rhs[index] : 0
            if left != right { return left > right }
        }
        return false
    }
}
