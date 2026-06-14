import Foundation

/// Turns raw records (+ optional live limits) into the snapshot every surface renders.
public struct SnapshotBuilder {
    public init() {}

    public func build(records: [UsageRecord], live: LiveLimits?, now: Date = Date()) -> UsageSnapshot {
        let store = UsageStore()
        func stat(_ t: TokenTotals) -> WindowStat {
            WindowStat(costUSD: t.cost, totalTokens: t.totalTokens, requests: t.requests)
        }

        let last5h  = store.window(records, since: now.addingTimeInterval(-5 * 3600), until: now)
        let last24h = store.window(records, since: now.addingTimeInterval(-24 * 3600), until: now)
        let last7d  = store.window(records, since: now.addingTimeInterval(-7 * 24 * 3600), until: now)
        let report  = store.aggregate(records)

        // Burn rate: tokens over the last 60 minutes of wall-clock.
        let recentHour = store.window(records, since: now.addingTimeInterval(-3600), until: now)
        let burnPerMin = Double(recentHour.totalTokens) / 60.0

        // Data driven: one row per model family actually seen in the logs (including
        // any new model), sorted by usage. No fixed list.
        let byModel = report.byModel
            .filter { $0.value.requests > 0 }
            .sorted { $0.value.totalTokens > $1.value.totalTokens }
            .map { ModelStat(family: ModelFamily.display(forToken: $0.key), costUSD: $0.value.cost, totalTokens: $0.value.totalTokens) }
        let topProjects = report.byProject
            .sorted { $0.value.cost > $1.value.cost }
            .map { ProjectStat(name: $0.key, costUSD: $0.value.cost, totalTokens: $0.value.totalTokens) }
        let recentDays = report.byDay
            .sorted { $0.key > $1.key }
            .prefix(14)
            .map { DayStat(day: $0.key, costUSD: $0.value.cost, totalTokens: $0.value.totalTokens) }

        var forecasts: [Forecast] = []
        if let wk = live?.sevenDay { forecasts.append(forecast(window: "weekly", limit: wk, totalSeconds: 7 * 24 * 3600, now: now)) }
        if let fh = live?.fiveHour { forecasts.append(forecast(window: "5h", limit: fh, totalSeconds: 5 * 3600, now: now)) }

        return UsageSnapshot(
            generatedAt: now,
            live: live,
            last5h: stat(last5h),
            last24h: stat(last24h),
            last7d: stat(last7d),
            allTime: stat(report.overall),
            byModel: byModel,
            topProjects: Array(topProjects),
            recentDays: Array(recentDays),
            tokenBurnPerMin: burnPerMin,
            forecasts: forecasts
        )
    }

    /// Linear projection: from the elapsed fraction of the window and the used %,
    /// estimate whether and when the window exhausts before its reset.
    func forecast(window: String, limit: LimitWindow, totalSeconds: Double, now: Date) -> Forecast {
        guard let reset = limit.resetsAt else {
            return Forecast(window: window, willExhaustBeforeReset: false, exhaustionDate: nil,
                            paceRatio: 0, summary: "no reset time available")
        }
        let secondsLeft = reset.timeIntervalSince(now)
        guard secondsLeft > 0 else {
            // Window already reset (stale data / clock skew): a forecast would be meaningless.
            return Forecast(window: window, willExhaustBeforeReset: false, exhaustionDate: nil,
                            paceRatio: 0, summary: "limits out of date")
        }
        // Clamp elapsed to the window length so a skewed reset can't understate the rate.
        let elapsed = min(totalSeconds, max(1, totalSeconds - secondsLeft))
        let elapsedFraction = max(0.0001, elapsed / totalSeconds)
        let expectedEvenUse = elapsedFraction * 100
        let paceRatio = expectedEvenUse > 0 ? limit.usedPercent / expectedEvenUse : 0

        // Project usage forward at the current average rate.
        let ratePerSecond = limit.usedPercent / elapsed     // % per second so far
        let willExhaust: Bool
        var exhaustionDate: Date?
        var summary: String
        if ratePerSecond <= 0 {
            willExhaust = false
            summary = "no usage yet this window"
        } else {
            let secondsToFull = (100 - limit.usedPercent) / ratePerSecond
            let projected = now.addingTimeInterval(secondsToFull)
            if secondsToFull < secondsLeft {
                willExhaust = true
                exhaustionDate = projected
                summary = "at this pace you hit the \(window) cap " + Self.relative(projected, from: now)
            } else {
                willExhaust = false
                summary = "on pace to finish the window with headroom to spare"
            }
        }
        return Forecast(window: window, willExhaustBeforeReset: willExhaust,
                        exhaustionDate: exhaustionDate, paceRatio: paceRatio, summary: summary)
    }

    static func relative(_ date: Date, from now: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "EEE h a"
        return "~" + f.string(from: date)
    }
}
