// Layer 3: UI Smoke Tests via macOS Accessibility APIs
//
// These tests launch the real app binary, interact with it through AXUIElement
// (the same accessibility tree XCUITest uses), and verify the popover works.
//
// Requirements:
//   - App must be built first: `swift build` from mac/
//   - System Preferences > Privacy & Security > Accessibility must include
//     your terminal app (Terminal.app, iTerm, etc.) for AX queries to work.
//   - Not suitable for headless CI — requires a display and accessibility perms.
//
// Run with: cd mac && swift test --filter ExeWatcherUITests
//
// These tests kill any existing ExeWatcherMenubar process on setUp and
// launch a fresh instance so they're hermetic.

import AppKit
import Foundation
import Testing

private let binaryName = "ExeWatcherMenubar"
private let launchTimeout: TimeInterval = 15
private let uiTimeout: TimeInterval = 10

// MARK: - AX Helpers

/// Thin wrapper around AXUIElement for readable test code.
private struct AXNode {
    let element: AXUIElement

    var role: String? { attribute(kAXRoleAttribute) }
    var title: String? { attribute(kAXTitleAttribute) }
    var value: String? { attribute(kAXValueAttribute) }
    var label: String? { attribute(kAXDescriptionAttribute) ?? attribute("AXLabel") }
    var identifier: String? { attribute(kAXIdentifierAttribute) }
    var subrole: String? { attribute(kAXSubroleAttribute) }

    func attribute<T>(_ name: String) -> T? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success else {
            return nil
        }
        return value as? T
    }

    var children: [AXNode] {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &value) == .success,
              let array = value as? [AXUIElement] else { return [] }
        return array.map { AXNode(element: $0) }
    }

    /// Recursively find all descendants matching a predicate.
    func findAll(where predicate: (AXNode) -> Bool) -> [AXNode] {
        var results: [AXNode] = []
        if predicate(self) { results.append(self) }
        for child in children {
            results.append(contentsOf: child.findAll(where: predicate))
        }
        return results
    }

    /// Find first descendant matching a predicate.
    func findFirst(where predicate: (AXNode) -> Bool) -> AXNode? {
        if predicate(self) { return self }
        for child in children {
            if let found = child.findFirst(where: predicate) { return found }
        }
        return nil
    }

    /// Perform AX press action (click).
    func press() {
        AXUIElementPerformAction(element, kAXPressAction as CFString)
    }

    /// All text content visible in the subtree (for debugging).
    func allText() -> [String] {
        findAll { node in
            node.role == kAXStaticTextRole as String
        }.compactMap { $0.value ?? $0.title ?? $0.label }
    }
}

// MARK: - Process management

/// Find the built binary. Prefers .app bundles (which register with the window
/// server properly) over raw SPM binaries (which don't get accessibility trees).
private func findBinaryPath() -> String? {
    let sourceFileURL = URL(fileURLWithPath: #filePath)
    let testsDir = sourceFileURL.deletingLastPathComponent()
    let macDir = testsDir.deletingLastPathComponent()
                         .deletingLastPathComponent()

    // 1. Packaged .app in .build/dist/ (best — has Info.plist, bundle ID, proper AX)
    let distApp = macDir.appendingPathComponent(".build/dist/Watcher by EXE.app/Contents/MacOS/\(binaryName)").path
    if FileManager.default.isExecutableFile(atPath: distApp) { return distApp }

    // 2. Installed .app bundles
    let appPaths = [
        "/Applications/Watcher by EXE.app/Contents/MacOS/\(binaryName)",
        "/Applications/Exe Watcher.app/Contents/MacOS/\(binaryName)",
        NSHomeDirectory() + "/Applications/Watcher by EXE.app/Contents/MacOS/\(binaryName)",
        NSHomeDirectory() + "/Applications/Exe Watcher.app/Contents/MacOS/\(binaryName)",
    ]
    for p in appPaths {
        if FileManager.default.isExecutableFile(atPath: p) { return p }
    }

    // 3. SPM release binary (no .app bundle — AX may not work)
    let releasePath = macDir.appendingPathComponent(".build/arm64-apple-macosx/release/\(binaryName)").path
    if FileManager.default.isExecutableFile(atPath: releasePath) { return releasePath }

    // 4. SPM debug binary (same caveat)
    let debugPath = macDir.appendingPathComponent(".build/arm64-apple-macosx/debug/\(binaryName)").path
    if FileManager.default.isExecutableFile(atPath: debugPath) { return debugPath }

    return nil
}

private func killExisting() {
    // Kill by bundle ID (packaged app)
    for bundleId in ["com.askexe.exe-watcher-menubar", "com.exeai.\(binaryName)"] {
        let running = NSRunningApplication.runningApplications(withBundleIdentifier: bundleId)
        for app in running { app.forceTerminate() }
    }
    // Also kill by process name in case bundle ID doesn't match (raw SPM binary)
    let task = Process()
    task.executableURL = URL(fileURLWithPath: "/usr/bin/pkill")
    task.arguments = ["-x", binaryName]
    try? task.run()
    task.waitUntilExit()
    Thread.sleep(forTimeInterval: 0.5)
}

/// Launch as a proper .app bundle via `open -a` so macOS registers it with the
/// window server and builds an accessibility tree. Falls back to direct Process
/// launch for raw binaries but warns that AX may not work.
private func launchApp(path: String) -> (process: Process?, pid: pid_t) {
    // If path is inside a .app bundle, use `open -a` for proper registration
    if let appBundlePath = extractAppBundlePath(from: path) {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        task.arguments = ["-a", appBundlePath, "--args", "--test-mode"]
        task.standardOutput = FileHandle.nullDevice
        task.standardError = FileHandle.nullDevice
        try! task.run()
        task.waitUntilExit()

        // `open` returns immediately; find the PID via NSWorkspace
        let deadline = Date().addingTimeInterval(launchTimeout)
        while Date() < deadline {
            let apps = NSWorkspace.shared.runningApplications
            if let app = apps.first(where: {
                $0.bundleIdentifier == "com.askexe.exe-watcher-menubar"
                || $0.localizedName == "Watcher by EXE"
                || $0.localizedName == binaryName
            }) {
                return (nil, app.processIdentifier)
            }
            Thread.sleep(forTimeInterval: 0.3)
        }
        // Fallback: couldn't find PID after open
        return (nil, -1)
    }

    // Raw binary fallback (SPM debug build — AX tree may be empty)
    let process = Process()
    process.executableURL = URL(fileURLWithPath: path)
    process.environment = ProcessInfo.processInfo.environment
    process.standardOutput = FileHandle.nullDevice
    process.standardError = FileHandle.nullDevice
    try! process.run()
    return (process, process.processIdentifier)
}

/// If the path is inside a .app bundle, return the bundle path.
/// E.g. ".../Watcher by EXE.app/Contents/MacOS/ExeWatcherMenubar" -> ".../Watcher by EXE.app"
private func extractAppBundlePath(from path: String) -> String? {
    let components = path.components(separatedBy: "/")
    for (i, component) in components.enumerated() {
        if component.hasSuffix(".app") {
            return components[0...i].joined(separator: "/")
        }
    }
    return nil
}

/// Check whether this process has Accessibility API permission.
private func hasAccessibilityPermission() -> Bool {
    // Try reading AX children of any running app. If we get kAXErrorAPIDisabled (-25211)
    // then we don't have permission.
    let apps = NSWorkspace.shared.runningApplications.filter { $0.activationPolicy == .regular }
    guard let app = apps.first else { return false }
    let el = AXUIElementCreateApplication(app.processIdentifier)
    var value: CFTypeRef?
    let result = AXUIElementCopyAttributeValue(el, kAXChildrenAttribute as CFString, &value)
    return result != .apiDisabled
}

/// Wait for the app's AX tree to become available.
private func waitForAppReady(pid: pid_t, timeout: TimeInterval) -> Bool {
    guard pid > 0 else { return false }
    let appElement = AXUIElementCreateApplication(pid)
    let deadline = Date().addingTimeInterval(timeout)
    while Date() < deadline {
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(appElement, kAXChildrenAttribute as CFString, &value)
        if result == .success, let children = value as? [AXUIElement], !children.isEmpty {
            return true
        }
        // If AX is disabled system-wide, don't keep waiting
        if result == .apiDisabled { return false }
        if kill(pid, 0) != 0 { return false }
        Thread.sleep(forTimeInterval: 0.5)
    }
    return false
}

/// Wait for a condition with polling.
private func waitUntil(timeout: TimeInterval = uiTimeout, interval: TimeInterval = 0.3, _ condition: () -> Bool) -> Bool {
    let deadline = Date().addingTimeInterval(timeout)
    while Date() < deadline {
        if condition() { return true }
        Thread.sleep(forTimeInterval: interval)
    }
    return false
}

// MARK: - Tests

@Suite("UI Smoke Tests", .serialized)
struct ExeWatcherUITests {
    /// Shared state across tests — launch once, reuse.
    /// Using .serialized ensures tests run in order.

    /// Launch the app and return its PID + AX node. Throws on failure.
    /// Returns `nil` appNode if accessibility permission is missing (tests should skip).
    private func launchAndGetApp() throws -> (pid: pid_t, appNode: AXNode?) {
        killExisting()

        guard let binaryPath = findBinaryPath() else {
            throw AppLaunchError.binaryNotFound
        }

        let (_, pid) = launchApp(path: binaryPath)
        guard pid > 0 else {
            throw AppLaunchError.didNotRegister
        }

        // Check if we even have accessibility permission
        if !hasAccessibilityPermission() {
            // App launched but we can't inspect it — tests will skip AX-dependent checks
            Thread.sleep(forTimeInterval: 2.0)  // give app time to start
            return (pid, nil)
        }

        // Wait for the AX tree to become available (status item rendered)
        guard waitForAppReady(pid: pid, timeout: launchTimeout) else {
            kill(pid, SIGTERM)
            throw AppLaunchError.noAccessibility
        }

        let appElement = AXUIElementCreateApplication(pid)
        let appNode = AXNode(element: appElement)

        Thread.sleep(forTimeInterval: 1.5)

        return (pid, appNode)
    }

    /// Find the menubar extra / status item via the system-wide accessibility element.
    private func findStatusItem() -> AXNode? {
        let systemWide = AXUIElementCreateSystemWide()
        let systemNode = AXNode(element: systemWide)

        // The menubar extras live under the system menu bar. Walk the AX tree
        // looking for a menu bar item whose title contains "$" (our cost label).
        // Alternatively look for "WATCHER" or the app name.
        return systemNode.findFirst { node in
            let t = node.title ?? ""
            let v = node.value ?? ""
            let l = node.label ?? ""
            let all = t + v + l
            return all.contains("$") && (node.role == kAXMenuBarItemRole as String || node.subrole == "AXMenuExtra")
        }
    }

    /// Find the popover window after clicking the status item.
    private func findPopoverWindow(appNode: AXNode) -> AXNode? {
        // After clicking, the popover creates a window. Look for it.
        return appNode.findFirst { node in
            node.role == kAXWindowRole as String || node.role == kAXSheetRole as String || node.role == "AXPopover"
        }
    }

    /// Run a test body that requires AX. If AX is unavailable, wraps the test
    /// in `withKnownIssue` so it doesn't count as a failure.
    private func withAX(body: (AXNode) throws -> Void) throws {
        let (pid, appNode) = try launchAndGetApp()
        defer { kill(pid, SIGTERM) }

        if let node = appNode {
            try body(node)
        } else {
            withKnownIssue("Accessibility permission not granted") {
                #expect(Bool(false), "Grant Accessibility in System Settings > Privacy & Security")
            }
        }
    }

    // ------------------------------------------------------------------
    // 1. App Launches (no AX needed — just check the process is alive)
    // ------------------------------------------------------------------
    @Test("app launches without crash and stays running for 2 seconds")
    func appLaunches() throws {
        let (pid, _) = try launchAndGetApp()
        defer { kill(pid, SIGTERM) }

        // Verify the process is still alive after launch
        #expect(kill(pid, 0) == 0, "Process should be running")

        // Wait 2 seconds and check it didn't crash
        Thread.sleep(forTimeInterval: 2.0)
        #expect(kill(pid, 0) == 0, "Process should still be running after 2 seconds")
    }

    // ------------------------------------------------------------------
    // 2. Status Item Exists (requires AX)
    // ------------------------------------------------------------------
    @Test("status bar item appears with a dollar cost label")
    func statusItemExists() throws {
        try withAX { _ in
            let found = waitUntil(timeout: uiTimeout) {
                findStatusItem() != nil
            }
            #expect(found, "Status bar item with '$' cost should appear in the menu bar")
        }
    }

    // ------------------------------------------------------------------
    // 3. Popover Opens (requires AX)
    // ------------------------------------------------------------------
    @Test("clicking the status item opens the popover with WATCHER header")
    func popoverOpens() throws {
        try withAX { node in
            guard let statusItem = findStatusItem() else {
                Issue.record("Could not find status item in the menu bar")
                return
            }
            statusItem.press()
            Thread.sleep(forTimeInterval: 1.0)

            let popoverFound = waitUntil(timeout: uiTimeout) {
                findPopoverWindow(appNode: node) != nil
            }
            #expect(popoverFound, "Popover window should appear after clicking status item")

            if let popover = findPopoverWindow(appNode: node) {
                let allTexts = popover.allText()
                let hasWatcher = allTexts.contains { $0.uppercased().contains("WATCHER") }
                #expect(hasWatcher, "Popover should contain 'WATCHER' header. Found texts: \(allTexts.prefix(10))")
            }
        }
    }

    // ------------------------------------------------------------------
    // 4. Cost Label Format (requires AX)
    // ------------------------------------------------------------------
    @Test("popover shows a cost label starting with '$'")
    func costLabelFormat() throws {
        try withAX { node in
            guard let statusItem = findStatusItem() else {
                Issue.record("Could not find status item")
                return
            }
            statusItem.press()
            Thread.sleep(forTimeInterval: 1.5)

            guard let popover = findPopoverWindow(appNode: node) else {
                Issue.record("Popover did not open")
                return
            }

            let allTexts = popover.allText()
            let hasDollar = allTexts.contains { $0.hasPrefix("$") }
            #expect(hasDollar, "At least one text element should start with '$'. Found: \(allTexts.prefix(10))")
        }
    }

    // ------------------------------------------------------------------
    // 5. Period Buttons Exist (requires AX)
    // ------------------------------------------------------------------
    @Test("popover contains all five period tab buttons")
    func periodButtonsExist() throws {
        try withAX { node in
            guard let statusItem = findStatusItem() else {
                Issue.record("Could not find status item")
                return
            }
            statusItem.press()
            Thread.sleep(forTimeInterval: 1.5)

            guard let popover = findPopoverWindow(appNode: node) else {
                Issue.record("Popover did not open")
                return
            }

            let expectedPeriods = ["Today", "7 Days", "30 Days", "Month", "All"]
            let buttons = popover.findAll { n in
                n.role == kAXButtonRole as String || n.role == kAXRadioButtonRole as String
            }
            let buttonTitles = buttons.compactMap { $0.title ?? $0.label ?? $0.value }

            for period in expectedPeriods {
                let found = buttonTitles.contains { $0 == period }
                #expect(found, "Period button '\(period)' should exist. Found buttons: \(buttonTitles.prefix(15))")
            }
        }
    }

    // ------------------------------------------------------------------
    // 6. Period Tab Switching (requires AX)
    // ------------------------------------------------------------------
    @Test("clicking each period tab updates the visible caption")
    func periodTabSwitching() throws {
        try withAX { node in
            guard let statusItem = findStatusItem() else {
                Issue.record("Could not find status item")
                return
            }
            statusItem.press()
            Thread.sleep(forTimeInterval: 1.5)

            guard let popover = findPopoverWindow(appNode: node) else {
                Issue.record("Popover did not open")
                return
            }

            let periodChecks: [(button: String, captionContains: String)] = [
                ("7 Days",  "7"),
                ("30 Days", "30"),
                ("Month",   "Month"),
                ("All",     "All"),
                ("Today",   "Today"),
            ]

            for (buttonLabel, expectedSubstring) in periodChecks {
                let buttons = popover.findAll { n in
                    (n.role == kAXButtonRole as String || n.role == kAXRadioButtonRole as String)
                    && (n.title == buttonLabel || n.label == buttonLabel || n.value == buttonLabel)
                }
                guard let button = buttons.first else {
                    Issue.record("Could not find button '\(buttonLabel)'")
                    continue
                }
                button.press()
                Thread.sleep(forTimeInterval: 1.0)

                let texts = popover.allText()
                let captionFound = texts.contains { $0.contains(expectedSubstring) }
                #expect(
                    captionFound,
                    "After clicking '\(buttonLabel)', expected text containing '\(expectedSubstring)'. Found: \(texts.prefix(10))"
                )
            }
        }
    }
}


// MARK: - Errors

private enum AppLaunchError: Error, CustomStringConvertible {
    case binaryNotFound
    case didNotRegister
    case noAccessibility

    var description: String {
        switch self {
        case .binaryNotFound:
            return "Could not find \(binaryName) binary. Run `swift build` first."
        case .didNotRegister:
            return "\(binaryName) launched but did not register in NSWorkspace within \(launchTimeout)s."
        case .noAccessibility:
            return """
            \(binaryName) launched but accessibility tree is empty. \
            Grant accessibility permission to your terminal in \
            System Preferences > Privacy & Security > Accessibility.
            """
        }
    }
}
