import XCTest
@testable import HeadroomCore

final class EngineFixesTests: XCTestCase {

    // Percent scale: utilization is 0...1, used_percentage is already 0...100.
    func testUsedPercentageNotRenormalized() {
        let json = Data(#"{"seven_day":{"used_percentage":73}}"#.utf8)
        XCTAssertEqual(LiveLimitsClient.parseClaudeUsage(json)?.sevenDay?.usedPercent ?? -1, 73, accuracy: 0.001)
    }
    func testUtilizationIsRaw() {
        // claude.ai /usage utilization is already a 0...100 percentage.
        let json = Data(#"{"seven_day":{"utilization":41}}"#.utf8)
        XCTAssertEqual(LiveLimitsClient.parseClaudeUsage(json)?.sevenDay?.usedPercent ?? -1, 41, accuracy: 0.001)
    }

    // Forecast must not project on an already-reset window.
    func testForecastPastResetIsInert() {
        let f = SnapshotBuilder().forecast(
            window: "weekly",
            limit: LimitWindow(usedPercent: 99, resetsAt: Date(timeIntervalSinceNow: -100)),
            totalSeconds: 7 * 24 * 3600, now: Date())
        XCTAssertFalse(f.willExhaustBeforeReset)
        XCTAssertEqual(f.summary, "limits out of date")
    }
    func testForecastExhaustsWhenOverPaced() {
        let now = Date()
        let f = SnapshotBuilder().forecast(
            window: "weekly",
            limit: LimitWindow(usedPercent: 80, resetsAt: now.addingTimeInterval(3600)),
            totalSeconds: 7200, now: now)
        XCTAssertTrue(f.willExhaustBeforeReset)
        XCTAssertNotNil(f.exhaustionDate)
    }

    // Dedup keeps the largest record per requestId and skips synthetic models.
    func testDedupKeepsLargestAndSkipsSynthetic() throws {
        let fm = FileManager.default
        let root = fm.temporaryDirectory.appendingPathComponent("hr-\(UUID().uuidString)")
        let proj = root.appendingPathComponent("-proj")
        try fm.createDirectory(at: proj, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: root) }

        let lines = [
            #"{"type":"assistant","requestId":"r","timestamp":"2026-06-13T10:00:00Z","message":{"model":"claude-opus-4-8","usage":{"input_tokens":100,"output_tokens":10}}}"#,
            #"{"type":"assistant","requestId":"r","timestamp":"2026-06-13T10:00:01Z","message":{"model":"claude-opus-4-8","usage":{"input_tokens":500,"output_tokens":50}}}"#,
            #"{"type":"assistant","requestId":"s","timestamp":"2026-06-13T10:00:02Z","message":{"model":"<synthetic>","usage":{"input_tokens":9999,"output_tokens":9999}}}"#,
        ].joined(separator: "\n")
        try Data(lines.utf8).write(to: proj.appendingPathComponent("sess.jsonl"))

        let recs = UsageStore().loadRecords(projectsDir: root)
        XCTAssertEqual(recs.count, 1, "duplicate merged + synthetic excluded")
        XCTAssertEqual(recs.first?.inputTokens, 500, "kept the larger duplicate")
    }
}
