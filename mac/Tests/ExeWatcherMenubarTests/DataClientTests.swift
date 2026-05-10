import Testing
@testable import ExeWatcherMenubar

@Suite("DataClient commands")
struct DataClientCommandTests {
    @Test("every menubar period maps to the correct CLI args")
    func subcommandUsesExpectedPeriodAndProviderFlags() {
        let cases: [(Period, String)] = [
            (.today, "today"),
            (.sevenDays, "week"),
            (.thirtyDays, "30days"),
            (.month, "month"),
            (.all, "all"),
        ]

        for (period, expectedArg) in cases {
            let command = DataClient.subcommand(
                period: period,
                provider: .codex,
                includeOptimize: false
            )

            #expect(command.contains("--format"))
            #expect(command.contains("menubar-json"))
            #expect(command.contains("--provider"))
            #expect(command.contains("codex"))
            #expect(command.contains("--no-optimize"))
            if let periodIndex = command.firstIndex(of: "--period") {
                #expect(command[command.index(after: periodIndex)] == expectedArg)
            } else {
                Issue.record("Missing --period flag for \(period.rawValue)")
            }
        }
    }

    @Test("optimized refresh omits the no-optimize flag")
    func optimizedRefreshDoesNotForceNoOptimize() {
        let command = DataClient.subcommand(period: .today, provider: .all, includeOptimize: true)
        #expect(!command.contains("--no-optimize"))
    }
}

@Suite("DataClient user-facing errors")
struct DataClientErrorMessageTests {
    @Test("CLI not found gets a human-readable message")
    func cliNotFoundMessage() {
        let error = DataClientError.nonZeroExit(code: 127, stderr: "env: exe-watcher: No such file or directory\n")
        #expect(error.errorDescription == "The exe-watcher CLI was not found. Reinstall it (`npm install -g exe-watcher`) or set EXE_WATCHER_BIN.")
    }

    @Test("timeout gets a retryable message")
    func timeoutMessage() {
        let error = DataClientError.timeout
        #expect(error.errorDescription == "exe-watcher timed out after 60 seconds. Retry once the machine is idle.")
    }
}
