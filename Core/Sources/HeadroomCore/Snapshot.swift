import Foundation

/// On-disk locations Headroom uses to hand data between the collector, the CLI,
/// and (later) the app + widgets. The real app will swap this for an App Group
/// container; the path-shaped API stays the same.
public enum SupportDir {
    /// Shared container so the (sandboxed) widget extension can read what the app writes.
    public static let appGroupID = "group.ai.aivideoplatform.claude.usuage"

    public static var url: URL {
        let fm = FileManager.default
        if let group = fm.containerURL(forSecurityApplicationGroupIdentifier: appGroupID) {
            return group.appendingPathComponent("Headroom", isDirectory: true)
        }
        // Fallback (CLI / unentitled contexts): per-user Application Support.
        let base = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return base.appendingPathComponent("Headroom", isDirectory: true)
    }
    public static func ensure() {
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    }
    public static var liveJSON: URL { url.appendingPathComponent("live.json") }
    public static var snapshotJSON: URL { url.appendingPathComponent("snapshot.json") }
}

/// Persists the rendered snapshot so widgets (and a relaunched app) can read it.
public enum SnapshotStore {
    public static func save(_ snapshot: UsageSnapshot) {
        SupportDir.ensure()
        if let data = try? HeadroomJSON.encoder.encode(snapshot) {
            try? data.write(to: SupportDir.snapshotJSON)
        }
    }
    public static func load() -> UsageSnapshot? {
        guard let data = try? Data(contentsOf: SupportDir.snapshotJSON) else { return nil }
        return try? HeadroomJSON.decoder.decode(UsageSnapshot.self, from: data)
    }
}

public enum HeadroomJSON {
    public static let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        e.outputFormatting = [.prettyPrinted, .sortedKeys]
        return e
    }()
    public static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()
}

// MARK: - Live limits (from the statusline hook or, later, the OAuth endpoint)

public struct LimitWindow: Codable, Sendable {
    public var usedPercent: Double
    public var resetsAt: Date?
    public init(usedPercent: Double, resetsAt: Date?) {
        self.usedPercent = usedPercent
        self.resetsAt = resetsAt
    }
    public var remainingPercent: Double { max(0, 100 - usedPercent) }
}

/// A named weekly model sub limit, derived from whatever model buckets the API
/// actually returns (so new models appear automatically, by their real name).
public struct ModelWindow: Codable, Sendable {
    public var name: String
    public var window: LimitWindow
    public init(name: String, window: LimitWindow) { self.name = name; self.window = window }
}

public struct LiveLimits: Codable, Sendable {
    public var capturedAt: Date
    public var plan: String?
    public var fiveHour: LimitWindow?
    public var sevenDay: LimitWindow?
    public var sevenDayOpus: LimitWindow?
    public var sevenDaySonnet: LimitWindow?
    /// Every weekly per model sub limit the API returned, data driven. Optional so
    /// older cached payloads without this key still decode.
    public var weeklyByModel: [ModelWindow]?
    /// Extra-usage / purchased credits (claude.ai web path only).
    public var overageRemaining: Double?
    public var overageMonthlyLimit: Double?
    public var overageUsed: Double?
    public var overageCurrency: String?
    /// Where these values came from: "oauth-headers" | "claude-web" | "statusline" | "cache".
    public var source: String?

    public init(capturedAt: Date, plan: String? = nil,
                fiveHour: LimitWindow? = nil, sevenDay: LimitWindow? = nil,
                sevenDayOpus: LimitWindow? = nil, sevenDaySonnet: LimitWindow? = nil,
                weeklyByModel: [ModelWindow]? = nil,
                overageRemaining: Double? = nil, overageMonthlyLimit: Double? = nil,
                overageUsed: Double? = nil, overageCurrency: String? = nil,
                source: String? = nil) {
        self.capturedAt = capturedAt
        self.plan = plan
        self.fiveHour = fiveHour
        self.sevenDay = sevenDay
        self.sevenDayOpus = sevenDayOpus
        self.sevenDaySonnet = sevenDaySonnet
        self.weeklyByModel = weeklyByModel
        self.overageRemaining = overageRemaining
        self.overageMonthlyLimit = overageMonthlyLimit
        self.overageUsed = overageUsed
        self.overageCurrency = overageCurrency
        self.source = source
    }

    public var hasOverage: Bool { overageRemaining != nil || overageMonthlyLimit != nil }
}

// MARK: - The render contract every surface consumes

public struct WindowStat: Codable, Sendable {
    public var costUSD: Double
    public var totalTokens: Int
    public var requests: Int
    public init(costUSD: Double, totalTokens: Int, requests: Int) {
        self.costUSD = costUSD; self.totalTokens = totalTokens; self.requests = requests
    }
}

public struct ModelStat: Codable, Sendable {
    public var family: String
    public var costUSD: Double
    public var totalTokens: Int
}

public struct ProjectStat: Codable, Sendable {
    public var name: String
    public var costUSD: Double
    public var totalTokens: Int
}

public struct DayStat: Codable, Sendable {
    public var day: String
    public var costUSD: Double
    public var totalTokens: Int
}

/// A plain-language projection for one limit window.
public struct Forecast: Codable, Sendable {
    public var window: String          // "weekly", "5h"
    public var willExhaustBeforeReset: Bool
    public var exhaustionDate: Date?
    public var paceRatio: Double       // used% vs even-pace% (>1 means burning too fast)
    public var summary: String
}

public struct UsageSnapshot: Codable, Sendable {
    public static let schemaVersion = 1
    public var schema: Int = UsageSnapshot.schemaVersion
    public var generatedAt: Date
    public var live: LiveLimits?
    public var last5h: WindowStat
    public var last24h: WindowStat
    public var last7d: WindowStat
    public var allTime: WindowStat
    public var byModel: [ModelStat]
    public var topProjects: [ProjectStat]
    public var recentDays: [DayStat]
    public var tokenBurnPerMin: Double
    public var forecasts: [Forecast]
}

public extension UsageSnapshot {
    /// A representative snapshot for SwiftUI previews, widget placeholders, and
    /// graceful fallback when no real data is available (e.g. on a sandboxed iOS
    /// device before the first iCloud sync). Numbers mirror a real heavy-user week.
    static var sample: UsageSnapshot {
        let now = Date()
        let weekReset = now.addingTimeInterval(4 * 86_400 + 6 * 3_600)
        return UsageSnapshot(
            generatedAt: now,
            live: LiveLimits(
                capturedAt: now, plan: "Max ($200)",
                fiveHour: LimitWindow(usedPercent: 31, resetsAt: now.addingTimeInterval(2 * 3_600 + 840)),
                sevenDay: LimitWindow(usedPercent: 41, resetsAt: weekReset),
                sevenDayOpus: LimitWindow(usedPercent: 68, resetsAt: weekReset),
                sevenDaySonnet: LimitWindow(usedPercent: 22, resetsAt: weekReset)),
            last5h: WindowStat(costUSD: 154.2, totalTokens: 52_000_000, requests: 155),
            last24h: WindowStat(costUSD: 278.5, totalTokens: 160_000_000, requests: 498),
            last7d: WindowStat(costUSD: 1_599, totalTokens: 945_000_000, requests: 2_478),
            allTime: WindowStat(costUSD: 5_636, totalTokens: 2_617_000_000, requests: 15_519),
            byModel: [
                ModelStat(family: "Opus", costUSD: 5_474, totalTokens: 2_325_000_000),
                ModelStat(family: "Sonnet", costUSD: 1.6, totalTokens: 3_000_000),
                ModelStat(family: "Other", costUSD: 160, totalTokens: 288_000_000),
            ],
            topProjects: [
                ProjectStat(name: "Video", costUSD: 1_854, totalTokens: 830_000_000),
                ProjectStat(name: "Music", costUSD: 1_766, totalTokens: 709_000_000),
                ProjectStat(name: "index", costUSD: 848, totalTokens: 452_000_000),
                ProjectStat(name: "Whitening", costUSD: 546, totalTokens: 348_000_000),
            ],
            recentDays: (0..<14).reversed().map { i in
                DayStat(day: "d\(i)", costUSD: Double((i * 53) % 380) + 50, totalTokens: 0)
            },
            tokenBurnPerMin: 120_000,
            forecasts: [
                Forecast(window: "weekly", willExhaustBeforeReset: true,
                         exhaustionDate: now.addingTimeInterval(3 * 86_400 + 5 * 3_600),
                         paceRatio: 1.05, summary: "at this pace you hit the weekly cap ~Wed 6 AM"),
                Forecast(window: "5h", willExhaustBeforeReset: false, exhaustionDate: nil,
                         paceRatio: 0.57, summary: "on pace with headroom to spare"),
            ]
        )
    }
}
