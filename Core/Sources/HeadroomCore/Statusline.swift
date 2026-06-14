import Foundation

/// Parses the JSON payload Claude Code pipes into a statusline command on stdin.
/// We only need the `rate_limits` block, which is the single zero-network source
/// of the live 5-hour and weekly limit percentages and reset times.
public enum Statusline {

    private struct Root: Decodable { let rate_limits: Limits? }
    private struct Limits: Decodable {
        let five_hour: Window?
        let seven_day: Window?
        let seven_day_opus: Window?
        let seven_day_sonnet: Window?
    }
    private struct Window: Decodable {
        let used_percentage: Double?
        let resets_at: Double?   // unix epoch seconds
    }

    /// Returns nil if the payload has no rate-limit data (e.g. API-key users).
    public static func parse(_ data: Data, capturedAt: Date = Date()) -> LiveLimits? {
        guard let root = try? JSONDecoder().decode(Root.self, from: data),
              let limits = root.rate_limits else { return nil }

        func map(_ w: Window?) -> LimitWindow? {
            guard let w, let used = w.used_percentage else { return nil }
            let reset = w.resets_at.map { Date(timeIntervalSince1970: $0) }
            return LimitWindow(usedPercent: used, resetsAt: reset)
        }

        let live = LiveLimits(
            capturedAt: capturedAt,
            plan: nil,
            fiveHour: map(limits.five_hour),
            sevenDay: map(limits.seven_day),
            sevenDayOpus: map(limits.seven_day_opus),
            sevenDaySonnet: map(limits.seven_day_sonnet)
        )
        // If everything came back nil there is nothing useful to keep.
        if live.fiveHour == nil && live.sevenDay == nil { return nil }
        return live
    }

    /// A compact one-line gauge to print back to Claude Code's status line.
    public static func renderLine(_ live: LiveLimits) -> String {
        var parts: [String] = []
        if let wk = live.sevenDay { parts.append("wk \(Int(wk.usedPercent.rounded()))%") }
        if let fh = live.fiveHour { parts.append("5h \(Int(fh.usedPercent.rounded()))%") }
        return parts.isEmpty ? "Headroom: no limit data" : "◔ " + parts.joined(separator: " · ")
    }
}
