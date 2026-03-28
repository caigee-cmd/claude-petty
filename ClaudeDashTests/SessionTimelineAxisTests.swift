import XCTest
@testable import ClaudeGlance

final class SessionTimelineAxisTests: XCTestCase {
    func testTicksIncludeEndOfDayWithoutInvalidHour() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!

        let start = calendar.date(from: DateComponents(year: 2026, month: 3, day: 24, hour: 0))!
        let end = calendar.date(byAdding: .day, value: 1, to: start)!

        let ticks = SessionTimelineAxis.ticks(
            for: (start: start, end: end),
            stepHours: 4,
            calendar: calendar
        )

        XCTAssertEqual(ticks.map(\.hourOffset), [0, 4, 8, 12, 16, 20, 24])
        XCTAssertEqual(ticks.last?.label, "24:00")
    }

    func testTicksReturnEmptyForMissingRange() {
        XCTAssertEqual(SessionTimelineAxis.ticks(for: nil), [])
    }
}

final class HistoryScannerCacheTests: XCTestCase {
    func testScanReusesCachedSessionWhenFileMetadataIsUnchanged() throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }
        let baseDir = tempDir.appendingPathComponent(".claude/projects/-Users-cj-test", isDirectory: true)
        let cacheURL = tempDir.appendingPathComponent("history-cache.json")

        try FileManager.default.createDirectory(at: baseDir, withIntermediateDirectories: true)

        let transcriptURL = baseDir.appendingPathComponent("session-1.jsonl")
        let originalContent = """
        {"timestamp":"2026-03-24T01:00:00.000Z","type":"user","message":{"content":[{"type":"text","text":"hello"}]}}
        {"timestamp":"2026-03-24T01:05:00.000Z","type":"assistant","message":{"model":"claude-opus-4-20250101","usage":{"input_tokens":100,"output_tokens":50},"content":[{"type":"tool_use","name":"Read"},{"type":"text","text":"done"}]}}
        """

        try originalContent.write(to: transcriptURL, atomically: true, encoding: .utf8)
        let originalAttributes = try FileManager.default.attributesOfItem(atPath: transcriptURL.path)
        let originalDate = try XCTUnwrap(originalAttributes[.modificationDate] as? Date)
        let originalSize = try XCTUnwrap(originalAttributes[.size] as? NSNumber)

        let firstScan = HistoryScanner.scanAll(in: tempDir.appendingPathComponent(".claude/projects"), cacheFileURL: cacheURL)
        XCTAssertEqual(firstScan.count, 1)
        XCTAssertEqual(firstScan.first?.toolUseCount, 1)

        let invalidContent = String(repeating: "x", count: originalSize.intValue)
        try invalidContent.write(to: transcriptURL, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.modificationDate: originalDate], ofItemAtPath: transcriptURL.path)

        let secondScan = HistoryScanner.scanAll(in: tempDir.appendingPathComponent(".claude/projects"), cacheFileURL: cacheURL)
        XCTAssertEqual(secondScan.count, 1)
        XCTAssertEqual(secondScan.first?.toolUseCount, 1)
        XCTAssertTrue(FileManager.default.fileExists(atPath: cacheURL.path))
    }

    func testScanInvalidatesCacheWhenFileMetadataChanges() throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }
        let baseDir = tempDir.appendingPathComponent(".claude/projects/-Users-cj-test", isDirectory: true)
        let cacheURL = tempDir.appendingPathComponent("history-cache.json")

        try FileManager.default.createDirectory(at: baseDir, withIntermediateDirectories: true)

        let transcriptURL = baseDir.appendingPathComponent("session-2.jsonl")
        let firstContent = """
        {"timestamp":"2026-03-24T02:00:00.000Z","type":"user","message":{"content":[{"type":"text","text":"hello"}]}}
        {"timestamp":"2026-03-24T02:05:00.000Z","type":"assistant","message":{"model":"claude-opus-4-20250101","usage":{"input_tokens":100,"output_tokens":50},"content":[{"type":"text","text":"done"}]}}
        """
        let secondContent = """
        {"timestamp":"2026-03-24T02:00:00.000Z","type":"user","message":{"content":[{"type":"text","text":"hello"}]}}
        {"timestamp":"2026-03-24T02:05:00.000Z","type":"assistant","message":{"model":"claude-opus-4-20250101","usage":{"input_tokens":100,"output_tokens":50},"content":[{"type":"tool_use","name":"Read"},{"type":"text","text":"done"}]}}
        """

        try firstContent.write(to: transcriptURL, atomically: true, encoding: .utf8)
        _ = HistoryScanner.scanAll(in: tempDir.appendingPathComponent(".claude/projects"), cacheFileURL: cacheURL)

        Thread.sleep(forTimeInterval: 1.1)
        try secondContent.write(to: transcriptURL, atomically: true, encoding: .utf8)

        let refreshedScan = HistoryScanner.scanAll(in: tempDir.appendingPathComponent(".claude/projects"), cacheFileURL: cacheURL)
        XCTAssertEqual(refreshedScan.count, 1)
        XCTAssertEqual(refreshedScan.first?.toolUseCount, 1)
    }
}

final class SessionDirectoryScannerTests: XCTestCase {
    func testScanDetectsFreshTranscriptAndCompletesStaleTrackedTranscript() throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let projectsDir = tempDir.appendingPathComponent(".claude/projects", isDirectory: true)
        let projectDir = projectsDir.appendingPathComponent("-Users-cj-demo", isDirectory: true)
        try FileManager.default.createDirectory(at: projectDir, withIntermediateDirectories: true)

        let now = Date()
        let activeURL = projectDir.appendingPathComponent("active.jsonl")
        let staleURL = projectDir.appendingPathComponent("stale.jsonl")
        try "{}\n".write(to: activeURL, atomically: true, encoding: .utf8)
        try "{}\n".write(to: staleURL, atomically: true, encoding: .utf8)

        try FileManager.default.setAttributes(
            [.modificationDate: now.addingTimeInterval(-5)],
            ofItemAtPath: activeURL.path
        )
        try FileManager.default.setAttributes(
            [.modificationDate: now.addingTimeInterval(-180)],
            ofItemAtPath: staleURL.path
        )

        let result = SessionDirectoryScanner.scan(
            baseDir: projectsDir.path,
            trackedActivity: [staleURL.path: true],
            activeThreshold: 30,
            completionThreshold: 90,
            now: now
        )

        XCTAssertEqual(result.activeFiles.map(\.path), [activeURL.path])
        XCTAssertEqual(result.activeFiles.first?.projectName, "demo")
        XCTAssertEqual(result.completedPaths, [staleURL.path])
    }
}

final class HookInstallerConfigurationTests: XCTestCase {
    func testHookStatusReportsMissingWhenEnhancedHookIsAbsent() {
        let settings: [String: Any] = [
            "hooks": [
                "Stop": [
                    ["type": "command", "command": "/usr/bin/other-helper"]
                ]
            ]
        ]

        let status = HookInstaller.hookStatus(
            for: settings,
            helperCommand: "/Applications/ClaudeDash.app/Contents/Resources/ClaudeDashHelper",
            helperIsExecutable: true
        )

        XCTAssertEqual(status, .missing)
    }

    func testMergeStopHookPreservesExistingEntriesAndAppendsHelper() throws {
        let originalSettings: [String: Any] = [
            "hooks": [
                "Stop": [
                    ["type": "command", "command": "/usr/bin/existing-hook"]
                ]
            ]
        ]

        let result = HookInstaller.mergeStopHook(
            into: originalSettings,
            helperCommand: "/Applications/ClaudeDash.app/Contents/Resources/ClaudeDashHelper"
        )

        XCTAssertEqual(result.outcome, .installed)
        let hooks = try XCTUnwrap(result.settings["hooks"] as? [String: Any])
        let stopHooks = try XCTUnwrap(hooks["Stop"] as? [[String: Any]])
        XCTAssertEqual(stopHooks.count, 2)
        XCTAssertEqual(stopHooks.first?["command"] as? String, "/usr/bin/existing-hook")
        XCTAssertEqual(stopHooks.last?["command"] as? String, "/Applications/ClaudeDash.app/Contents/Resources/ClaudeDashHelper")
    }
}
