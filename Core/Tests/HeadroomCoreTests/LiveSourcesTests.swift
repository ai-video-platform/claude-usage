import XCTest
@testable import HeadroomCore

final class LiveSourcesTests: XCTestCase {

    func testRateLimitHeaderParsing() {
        let h = [
            "anthropic-ratelimit-unified-5h-utilization": "0.314",
            "anthropic-ratelimit-unified-7d-utilization": "0.412",
            "anthropic-ratelimit-unified-7d-reset": "1781000000",
        ]
        let live = LiveLimitsClient.parseRateLimitHeaders(h)
        XCTAssertEqual(live?.fiveHour?.usedPercent ?? -1, 31.4, accuracy: 0.01)
        XCTAssertEqual(live?.sevenDay?.usedPercent ?? -1, 41.2, accuracy: 0.01)
        XCTAssertNotNil(live?.sevenDay?.resetsAt)
        XCTAssertEqual(live?.source, "oauth-headers")
    }

    func testRateLimitHeadersAbsentReturnsNil() {
        XCTAssertNil(LiveLimitsClient.parseRateLimitHeaders([:]))
    }

    func testClaudeUsageParsing() {
        let json = Data("""
        {"five_hour":{"utilization":31,"resets_at":"2026-06-13T17:55:00Z"},
         "seven_day":{"utilization":41,"resets_at":1781000000},
         "seven_day_opus":{"utilization":68},
         "seven_day_sonnet":{"utilization":22}}
        """.utf8)
        let live = LiveLimitsClient.parseClaudeUsage(json)
        XCTAssertEqual(live?.fiveHour?.usedPercent ?? -1, 31, accuracy: 0.5)
        XCTAssertNotNil(live?.fiveHour?.resetsAt)
        XCTAssertEqual(live?.sevenDayOpus?.usedPercent ?? -1, 68, accuracy: 0.5)
        XCTAssertEqual(live?.sevenDaySonnet?.usedPercent ?? -1, 22, accuracy: 0.5)
        XCTAssertEqual(live?.source, "claude-web")
    }

    func testOverageGrantAndLimit() {
        var live = LiveLimits(capturedAt: Date())
        // The API returns credits in integer cents; we expose dollars.
        LiveLimitsClient.applyOverageGrant(Data(#"{"remaining_balance":4736,"currency":"USD"}"#.utf8), to: &live)
        XCTAssertEqual(live.overageRemaining ?? -1, 47.36, accuracy: 0.001)
        XCTAssertEqual(live.overageCurrency, "USD")

        LiveLimitsClient.applyOverageLimit(Data(#"{"is_enabled":true,"monthly_credit_limit":10000,"used_credits":1250}"#.utf8), to: &live)
        XCTAssertEqual(live.overageMonthlyLimit ?? -1, 100, accuracy: 0.001)
        XCTAssertEqual(live.overageUsed ?? -1, 12.5, accuracy: 0.001)
        XCTAssertTrue(live.hasOverage)
    }

    func testOverageDisabledIsIgnored() {
        var live = LiveLimits(capturedAt: Date())
        LiveLimitsClient.applyOverageLimit(Data(#"{"is_enabled":false,"monthly_credit_limit":10000}"#.utf8), to: &live)
        XCTAssertNil(live.overageMonthlyLimit)
        XCTAssertFalse(live.hasOverage)
    }

    func testTokenExtraction() {
        XCTAssertEqual(
            CredentialStore.extractAccessToken(from: Data(#"{"claudeAiOauth":{"accessToken":"abc123"}}"#.utf8)),
            "abc123")
        XCTAssertEqual(
            CredentialStore.extractAccessToken(from: Data(#"{"accessToken":"xyz"}"#.utf8)),
            "xyz")
        XCTAssertNil(CredentialStore.extractAccessToken(from: Data(#"{"nope":1}"#.utf8)))
    }

    func testPercentNormalization() {
        XCTAssertEqual(LiveLimitsClient.normalizePercent(0.5), 50, accuracy: 0.001)   // fraction
        XCTAssertEqual(LiveLimitsClient.normalizePercent(73), 73, accuracy: 0.001)    // already percent
    }
}
