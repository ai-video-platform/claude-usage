import XCTest
@testable import HeadroomCore

final class HeadroomCoreTests: XCTestCase {

    func testModelFamilyClassification() {
        XCTAssertEqual(ModelFamily(model: "claude-opus-4-8"), .opus)
        XCTAssertEqual(ModelFamily(model: "claude-sonnet-4-6"), .sonnet)
        XCTAssertEqual(ModelFamily(model: "claude-haiku-4-5-20251001"), .haiku)
        XCTAssertEqual(ModelFamily(model: "something-else"), .other)
    }

    func testPricingMatchesHandComputedCost() {
        // 1M input, 1M output on Opus = $15 + $75 = $90.
        let r = UsageRecord(
            requestId: "r1", model: "claude-opus-4-8", timestamp: Date(),
            inputTokens: 1_000_000, outputTokens: 1_000_000,
            cacheCreate5m: 0, cacheCreate1h: 0, cacheCreateOther: 0,
            cacheReadTokens: 0, project: "p", sessionId: "s")
        XCTAssertEqual(Pricing.cost(for: r), 90.0, accuracy: 0.0001)
    }

    func testCachePricingMultipliers() {
        // 1M cache read on Sonnet = 1M * $3/M * 0.10 = $0.30.
        let r = UsageRecord(
            requestId: "r2", model: "claude-sonnet-4-6", timestamp: Date(),
            inputTokens: 0, outputTokens: 0,
            cacheCreate5m: 0, cacheCreate1h: 0, cacheCreateOther: 0,
            cacheReadTokens: 1_000_000, project: "p", sessionId: "s")
        XCTAssertEqual(Pricing.cost(for: r), 0.30, accuracy: 0.0001)
    }

    func testAggregationGroupsAndDedupSemantics() {
        let now = Date()
        let recs = [
            UsageRecord(requestId: "a", model: "claude-opus-4-8", timestamp: now,
                        inputTokens: 100, outputTokens: 50, cacheCreate5m: 0, cacheCreate1h: 0,
                        cacheCreateOther: 0, cacheReadTokens: 0, project: "Alpha", sessionId: "s1"),
            UsageRecord(requestId: "b", model: "claude-sonnet-4-6", timestamp: now,
                        inputTokens: 200, outputTokens: 10, cacheCreate5m: 0, cacheCreate1h: 0,
                        cacheCreateOther: 0, cacheReadTokens: 0, project: "Beta", sessionId: "s2"),
        ]
        let report = UsageStore().aggregate(recs)
        XCTAssertEqual(report.overall.requests, 2)
        XCTAssertEqual(report.sessions.count, 2)
        XCTAssertNotNil(report.byModel["opus"])
        XCTAssertNotNil(report.byModel["sonnet"])
        XCTAssertEqual(report.byProject.count, 2)
    }
}
