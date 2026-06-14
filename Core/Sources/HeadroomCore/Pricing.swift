import Foundation

/// Per-token prices for a model family. Values are estimates and fully configurable.
/// Subscription cost figures are necessarily estimates: Claude Code stores no billed
/// cost in the transcripts (the `costUSD` field is always null), so we derive it here.
public struct ModelPrice: Sendable {
    public let inputPerMTok: Double
    public let outputPerMTok: Double

    public init(inputPerMTok: Double, outputPerMTok: Double) {
        self.inputPerMTok = inputPerMTok
        self.outputPerMTok = outputPerMTok
    }

    public var inputPerToken: Double { inputPerMTok / 1_000_000 }
    public var outputPerToken: Double { outputPerMTok / 1_000_000 }
}

public enum Pricing {
    /// USD per million tokens. Update these as Anthropic pricing changes.
    public static let table: [ModelFamily: ModelPrice] = [
        .opus:   ModelPrice(inputPerMTok: 15, outputPerMTok: 75),
        .sonnet: ModelPrice(inputPerMTok: 3,  outputPerMTok: 15),
        .haiku:  ModelPrice(inputPerMTok: 1,  outputPerMTok: 5),
        .other:  ModelPrice(inputPerMTok: 3,  outputPerMTok: 15),
    ]

    // Anthropic cache pricing relative to the base input price.
    public static let cacheWrite5mMultiplier = 1.25
    public static let cacheWrite1hMultiplier = 2.0
    public static let cacheReadMultiplier = 0.10

    public static func price(for model: String) -> ModelPrice {
        table[ModelFamily(model: model)] ?? table[.other]!
    }

    /// Estimated USD cost for a single usage record, pricing each token class correctly.
    public static func cost(for r: UsageRecord) -> Double {
        let p = price(for: r.model)
        let inTok = p.inputPerToken
        let input   = Double(r.inputTokens)  * inTok
        let output  = Double(r.outputTokens) * p.outputPerToken
        let write5  = Double(r.cacheCreate5m)    * inTok * cacheWrite5mMultiplier
        let write1h = Double(r.cacheCreate1h)    * inTok * cacheWrite1hMultiplier
        let writeO  = Double(r.cacheCreateOther) * inTok * cacheWrite5mMultiplier
        let read    = Double(r.cacheReadTokens)  * inTok * cacheReadMultiplier
        return input + output + write5 + write1h + writeO + read
    }
}
