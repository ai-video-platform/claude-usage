//
//  Formatting.swift
//  Claude Usage
//
//  Shared formatting and the pace math (used % vs elapsed % of a window).
//

import Foundation

/// The two real time windows. Reset times always come from the data's resetsAt;
/// these lengths are only used to compute how far through a window we are.
enum UsageWindow {
    static let session: TimeInterval = 5 * 3_600      // rolling 5 hour limit
    static let weekly: TimeInterval = 7 * 86_400      // 7 day window
}

enum Fmt {
    static func usd(_ v: Double) -> String {
        v >= 1000 ? String(format: "$%.0f", v) : String(format: "$%.2f", v)
    }
    static func tok(_ n: Int) -> String {
        if n >= 1_000_000_000 { return String(format: "%.1fB", Double(n) / 1_000_000_000) }
        if n >= 1_000_000 { return String(format: "%.0fM", Double(n) / 1_000_000) }
        if n >= 1_000 { return String(format: "%.0fk", Double(n) / 1_000) }
        return "\(n)"
    }

    /// Short countdown for a gauge subtitle, for example "resets in 1h 12m" or "resets in 3d".
    static func countdown(to date: Date?) -> String {
        guard let date else { return "resets time unknown" }
        let s = max(0, date.timeIntervalSinceNow)
        let d = Int(s) / 86_400, h = (Int(s) % 86_400) / 3_600, m = (Int(s) % 3_600) / 60
        if d >= 1 { return "resets in \(d)d" }
        if h >= 1 { return "resets in \(h)h \(m)m" }
        return "resets in \(m)m"
    }

    /// Long form used in sentences, for example "in 3 days" or "in 5 hours".
    static func untilLong(_ date: Date?) -> String {
        guard let date else { return "soon" }
        let s = max(0, date.timeIntervalSinceNow)
        let d = Int(s) / 86_400, h = (Int(s) % 86_400) / 3_600, m = (Int(s) % 3_600) / 60
        if d >= 1 { return "in \(d) day\(d == 1 ? "" : "s")" }
        if h >= 1 { return "in \(h) hour\(h == 1 ? "" : "s")" }
        return "in \(max(1, m)) minute\(m == 1 ? "" : "s")"
    }

    /// Freshness for the header, for example "just now" or "2 min ago".
    static func ago(_ date: Date?) -> String {
        guard let date else { return "never" }
        let s = Int(max(0, Date().timeIntervalSince(date)))
        if s < 60 { return "just now" }
        if s < 3_600 { return "\(s / 60) min ago" }
        if s < 86_400 { return "\(s / 3_600)h ago" }
        return "\(s / 86_400)d ago"
    }

    /// A human day and hour, for example "Thursday around 4 PM" or "tomorrow around 9 AM".
    static func whenHour(_ date: Date) -> String {
        let cal = Calendar.current
        let rounded = roundedToHour(date)
        let hf = DateFormatter(); hf.dateFormat = "h a"
        let hour = hf.string(from: rounded)
        if cal.isDateInToday(date) { return "today around \(hour)" }
        if cal.isDateInTomorrow(date) { return "tomorrow around \(hour)" }
        let df = DateFormatter(); df.dateFormat = "EEEE"
        return "\(df.string(from: date)) around \(hour)"
    }

    private static func roundedToHour(_ date: Date) -> Date {
        let cal = Calendar.current
        let plusHalf = date.addingTimeInterval(30 * 60)
        return cal.date(bySettingHour: cal.component(.hour, from: plusHalf), minute: 0, second: 0, of: plusHalf) ?? date
    }
}

/// Pace math: how far through a window we are, and where the current burn lands.
enum Pace {
    /// Fraction of the window elapsed, 0 to 1. The gap between this and used% is the
    /// ahead or behind pace read.
    static func elapsedFraction(resetsAt: Date?, window: TimeInterval) -> Double? {
        guard let resetsAt, window > 0 else { return nil }
        let frac = 1 - (resetsAt.timeIntervalSinceNow / window)
        return min(1, max(0, frac))
    }

    /// used% over elapsed%. Above 1 means burning faster than even pace.
    static func ratio(usedPercent: Double, resetsAt: Date?, window: TimeInterval) -> Double? {
        guard let elapsed = elapsedFraction(resetsAt: resetsAt, window: window), elapsed > 0.01 else { return nil }
        return usedPercent / (elapsed * 100)
    }

    /// Projected moment the window hits 100% at the current burn rate, if that lands
    /// before the reset. Returns nil when it is too early to project or you will not run out.
    static func projectedExhaustion(usedPercent: Double, resetsAt: Date?, window: TimeInterval) -> Date? {
        guard let resetsAt, usedPercent > 1, usedPercent < 100 else { return nil }
        let elapsed = window - max(0, resetsAt.timeIntervalSinceNow)
        guard elapsed > 300 else { return nil }   // too early to be meaningful
        let ratePerSec = usedPercent / elapsed
        guard ratePerSec > 0 else { return nil }
        let secsToFull = (100 - usedPercent) / ratePerSec
        let date = Date().addingTimeInterval(secsToFull)
        return date < resetsAt ? date : nil
    }
}
