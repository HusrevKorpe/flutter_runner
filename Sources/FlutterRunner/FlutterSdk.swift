import Foundation

/// Picks the flutter executable for a project, honouring FVM.
///
/// Order: `.fvm/flutter_sdk` link → version from `.fvmrc` in the FVM cache →
/// `fvm flutter` → `flutter` on PATH. Calling the SDK binary directly (rather
/// than through the `fvm` wrapper) means Stop terminates flutter itself.
enum FlutterSdk {
    static func command(for project: URL?) -> String {
        guard let project else { return "flutter" }
        let fileManager = FileManager.default

        let linked = project.appendingPathComponent(".fvm/flutter_sdk/bin/flutter")
        if fileManager.isExecutableFile(atPath: linked.path) {
            return Shell.quote(linked.path)
        }

        let fvmrc = project.appendingPathComponent(".fvmrc")
        guard fileManager.fileExists(atPath: fvmrc.path) else { return "flutter" }

        if let version = fvmVersion(at: fvmrc) {
            let cache = ProcessInfo.processInfo.environment["FVM_CACHE_PATH"]
                ?? "\(NSHomeDirectory())/fvm"
            let cached = URL(fileURLWithPath: cache).appendingPathComponent("versions/\(version)/bin/flutter")
            if fileManager.isExecutableFile(atPath: cached.path) {
                return Shell.quote(cached.path)
            }
        }
        return "fvm flutter"
    }

    private static func fvmVersion(at url: URL) -> String? {
        guard let data = try? Data(contentsOf: url),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let version = json["flutter"] as? String,
              !version.isEmpty,
              !version.contains("/") else { return nil }
        return version
    }
}
