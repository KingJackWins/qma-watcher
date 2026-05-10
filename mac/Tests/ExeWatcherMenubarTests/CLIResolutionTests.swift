import Testing
@testable import ExeWatcherMenubar

@Suite("ExeWatcherCLI resolution")
struct ExeWatcherCLIResolutionTests {
    @Test("skips broken latest NVM bins and falls back to the newest working install")
    func resolvesNewestWorkingNvmBinary() {
        let fs = ExeWatcherCLI.ResolverFilesystem(
            isExecutable: { path in
                path == "/Users/test/.nvm/versions/node/v22.19.0/bin/exe-watcher"
            },
            listDirectory: { path in
                if path == "/Users/test/.nvm/versions/node" {
                    return ["v22.20.0", "v22.19.0", "v20.18.0"]
                }
                return []
            }
        )

        let resolved = ExeWatcherCLI.resolveBinaryPath(
            environment: [:],
            homeDirectory: "/Users/test",
            filesystem: fs
        )

        #expect(resolved == "/Users/test/.nvm/versions/node/v22.19.0/bin/exe-watcher")
    }

    @Test("prefers an existing PATH entry before scanning fallback directories")
    func prefersExistingPathEntry() {
        let fs = ExeWatcherCLI.ResolverFilesystem(
            isExecutable: { path in
                path == "/custom/bin/exe-watcher" || path == "/Users/test/.nvm/versions/node/v22.20.0/bin/exe-watcher"
            },
            listDirectory: { path in
                if path == "/Users/test/.nvm/versions/node" {
                    return ["v22.20.0"]
                }
                return []
            }
        )

        let resolved = ExeWatcherCLI.resolveBinaryPath(
            environment: ["PATH": "/custom/bin:/usr/bin"],
            homeDirectory: "/Users/test",
            filesystem: fs
        )

        #expect(resolved == "/custom/bin/exe-watcher")
    }
}
