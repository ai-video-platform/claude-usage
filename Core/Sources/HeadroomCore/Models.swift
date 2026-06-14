import Foundation

/// One deduplicated assistant turn parsed from a Claude Code JSONL transcript.
public struct UsageRecord: Sendable, Hashable, Codable {
    public let requestId: String
    public let model: String
    public let timestamp: Date
    public let inputTokens: Int
    public let outputTokens: Int
    public let cacheCreate5m: Int
    public let cacheCreate1h: Int
    public let cacheCreateOther: Int   // cache writes when the 5m/1h breakdown is absent
    public let cacheReadTokens: Int
    public let project: String
    public let sessionId: String

    public init(requestId: String, model: String, timestamp: Date,
                inputTokens: Int, outputTokens: Int,
                cacheCreate5m: Int, cacheCreate1h: Int, cacheCreateOther: Int,
                cacheReadTokens: Int, project: String, sessionId: String) {
        self.requestId = requestId
        self.model = model
        self.timestamp = timestamp
        self.inputTokens = inputTokens
        self.outputTokens = outputTokens
        self.cacheCreate5m = cacheCreate5m
        self.cacheCreate1h = cacheCreate1h
        self.cacheCreateOther = cacheCreateOther
        self.cacheReadTokens = cacheReadTokens
        self.project = project
        self.sessionId = sessionId
    }

    public var cacheWriteTokens: Int { cacheCreate5m + cacheCreate1h + cacheCreateOther }
    public var billedTokens: Int { inputTokens + outputTokens + cacheWriteTokens + cacheReadTokens }
}

/// Coarse model family used for pricing and the Opus vs Sonnet split.
public enum ModelFamily: String, Sendable, CaseIterable {
    case opus, sonnet, haiku, other

    public init(model: String) {
        let m = model.lowercased()
        if m.contains("opus") { self = .opus }
        else if m.contains("sonnet") { self = .sonnet }
        else if m.contains("haiku") { self = .haiku }
        else { self = .other }
    }

    public var display: String {
        switch self {
        case .opus: return "Opus"
        case .sonnet: return "Sonnet"
        case .haiku: return "Haiku"
        case .other: return "Other"
        }
    }

    /// Data driven family token parsed from the actual model id, for example
    /// "claude-opus-4-8-20251101" -> "opus", "claude-3-5-sonnet" -> "sonnet",
    /// and any future "claude-fable-5" -> "fable". No fixed list, so new models
    /// surface by their real name instead of collapsing into "other".
    public static func token(for model: String) -> String {
        for part in model.lowercased().split(separator: "-") {
            let s = String(part)
            if s == "claude" || s == "latest" || s == "preview" { continue }
            if Int(s) != nil { continue }                       // version number segment
            if s.contains(where: { $0.isLetter }) { return s }  // first real name token
        }
        return "other"
    }

    /// Title case a family token for display, for example "opus" -> "Opus".
    public static func display(forToken token: String) -> String {
        guard let first = token.first else { return "Other" }
        return first.uppercased() + token.dropFirst()
    }
}

/// Accumulating token + cost totals for any grouping (model, project, day, window).
public struct TokenTotals: Sendable, Equatable {
    public var input = 0
    public var output = 0
    public var cacheWrite = 0
    public var cacheRead = 0
    public var cost = 0.0
    public var requests = 0

    public init() {}

    public var totalTokens: Int { input + output + cacheWrite + cacheRead }

    public mutating func add(_ o: TokenTotals) {
        input += o.input
        output += o.output
        cacheWrite += o.cacheWrite
        cacheRead += o.cacheRead
        cost += o.cost
        requests += o.requests
    }
}

public extension UsageRecord {
    /// Token totals (including computed cost) contributed by this single record.
    var tokenTotals: TokenTotals {
        var t = TokenTotals()
        t.input = inputTokens
        t.output = outputTokens
        t.cacheWrite = cacheWriteTokens
        t.cacheRead = cacheReadTokens
        t.cost = Pricing.cost(for: self)
        t.requests = 1
        return t
    }
}

/// Aggregated view across all records.
public struct UsageReport: Sendable {
    public var overall = TokenTotals()
    public var byModel: [String: TokenTotals] = [:]
    public var byProject: [String: TokenTotals] = [:]
    public var byDay: [String: TokenTotals] = [:]   // keyed yyyy-MM-dd
    public var sessions: Set<String> = []
    public var firstSeen: Date?
    public var lastSeen: Date?

    public init() {}
}
