import Foundation

/// Single entry point for spawning the `exe-watcher` CLI. All callers route through here so the
/// binary argv is validated once and no code path ever passes user-influenced strings through
/// a shell (`/bin/zsh -c`, `open --args`, AppleScript). This closes the shell-injection attack
/// surface end-to-end.
enum ExeWatcherCLI {
    /// Matches a plain file path / program name: alphanumerics, dot, underscore, slash, hyphen,
    /// space. Deliberately excludes shell metacharacters (`$`, `;`, `&`, `|`, quotes, backticks,
    /// newlines) so a malicious `EXE_WATCHER_BIN="exe-watcher; rm -rf ~"` can't slip through.
    private static let safeArgPattern = try! NSRegularExpression(pattern: "^[A-Za-z0-9 ._/\\-]+$")

    /// PATH additions for GUI-launched apps, which otherwise get a minimal PATH that misses
    /// Homebrew and npm global installs. Includes dynamic NVM resolution since macOS GUI apps
    /// never source ~/.zshrc and NVM paths are the most common npm global binary location.
    private static let additionalPathEntries: [String] = {
        var entries = ["/opt/homebrew/bin", "/usr/local/bin"]
        let home = NSHomeDirectory()
        let nvmDir = ProcessInfo.processInfo.environment["NVM_DIR"] ?? "\(home)/.nvm"
        let fm = FileManager.default
        // Add the most recent NVM node version's bin directory
        let versionsPath = "\(nvmDir)/versions/node"
        if let versions = try? fm.contentsOfDirectory(atPath: versionsPath) {
            for version in versions.sorted(by: isNewerNodeVersion) {
                let binPath = "\(versionsPath)/\(version)/bin"
                if fm.fileExists(atPath: binPath) {
                    entries.append(binPath)
                    break
                }
            }
        }
        // Fallback: ~/.local/bin (common on Linux, some macOS setups)
        let localBin = "\(home)/.local/bin"
        if fm.fileExists(atPath: localBin) { entries.append(localBin) }
        return entries
    }()

    private static func isNewerNodeVersion(_ lhs: String, _ rhs: String) -> Bool {
        let left = lhs.split(separator: ".").map { Int($0.trimmingCharacters(in: CharacterSet(charactersIn: "v"))) ?? 0 }
        let right = rhs.split(separator: ".").map { Int($0.trimmingCharacters(in: CharacterSet(charactersIn: "v"))) ?? 0 }
        let count = max(left.count, right.count)
        for idx in 0..<count {
            let l = idx < left.count ? left[idx] : 0
            let r = idx < right.count ? right[idx] : 0
            if l != r { return l > r }
        }
        return lhs > rhs
    }

    /// Returns the argv that launches the CLI. Dev override via `EXE_WATCHER_BIN` is honoured only
    /// if every whitespace-delimited token passes `safeArgPattern`. Otherwise falls back to the
    /// plain `exe-watcher` name (resolved via PATH).
    static func baseArgv() -> [String] {
        guard let raw = ProcessInfo.processInfo.environment["EXE_WATCHER_BIN"], !raw.isEmpty else {
            return ["exe-watcher"]
        }
        let parts = raw.split(separator: " ", omittingEmptySubsequences: true).map(String.init)
        guard parts.allSatisfy(isSafe) else {
            NSLog("Exe Watcher: refusing unsafe EXE_WATCHER_BIN; using default 'exe-watcher'")
            return ["exe-watcher"]
        }
        return parts
    }

    /// Builds a `Process` that runs the CLI with the given subcommand args. Uses `/usr/bin/env`
    /// so PATH lookup happens without involving a shell, and augments PATH with Homebrew
    /// defaults. Caller sets stdout/stderr pipes and calls `run()`.
    static func makeProcess(subcommand: [String]) -> Process {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        var environment = ProcessInfo.processInfo.environment
        environment["PATH"] = augmentedPath(environment["PATH"] ?? "")
        process.environment = environment
        // `env --` treats everything following as argv, not VAR=val pairs -- guards against an
        // argument accidentally resembling an env assignment.
        process.arguments = ["--"] + baseArgv() + subcommand
        // Use .utility so macOS can throttle background work and App Nap can kick in.
        process.qualityOfService = .utility
        return process
    }

    static func isSafe(_ s: String) -> Bool {
        let range = NSRange(s.startIndex..<s.endIndex, in: s)
        return safeArgPattern.firstMatch(in: s, range: range) != nil
    }

    private static func augmentedPath(_ existing: String) -> String {
        var parts = existing.split(separator: ":", omittingEmptySubsequences: true).map(String.init)
        for extra in additionalPathEntries where !parts.contains(extra) {
            parts.append(extra)
        }
        return parts.joined(separator: ":")
    }
}
