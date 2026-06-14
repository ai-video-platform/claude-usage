//
//  DemoData.swift
//  Claude Usage
//
//  In memory only data for visual QA and App Store screenshots. Activated solely
//  by the CU_DEMO launch environment variable. It is NEVER written to the real
//  shared store, so it can never appear in the real app.
//

import Foundation
import HeadroomCore

enum DemoData {
    /// A representative Max (20x) account.
    static var snapshot: UsageSnapshot {
        let now = Date()
        let weekReset = now.addingTimeInterval(2 * 86_400 + 5 * 3_600)
        let live = LiveLimits(
            capturedAt: now,
            plan: "Max (20x)",
            fiveHour: LimitWindow(usedPercent: 17, resetsAt: now.addingTimeInterval(69 * 60)),
            sevenDay: LimitWindow(usedPercent: 17, resetsAt: weekReset),
            sevenDayOpus: LimitWindow(usedPercent: 41, resetsAt: weekReset),
            sevenDaySonnet: LimitWindow(usedPercent: 3, resetsAt: weekReset),
            weeklyByModel: [
                ModelWindow(name: "Opus", window: LimitWindow(usedPercent: 41, resetsAt: weekReset)),
                ModelWindow(name: "Sonnet", window: LimitWindow(usedPercent: 3, resetsAt: weekReset)),
            ],
            overageRemaining: 1.61,
            overageMonthlyLimit: 50,
            overageUsed: 48.39,
            overageCurrency: "USD",
            source: "claude-web")
        var snap = UsageSnapshot.sample
        snap.generatedAt = now
        snap.live = live
        return snap
    }

    /// Synthetic, in memory history. Not persisted.
    static var history: UsageHistory {
        let cal = Calendar.current
        let now = Date()
        var samples: [UsageSample] = []
        for i in stride(from: 24 * 6, through: 0, by: -1) {
            let t = now.addingTimeInterval(-Double(i) * 600)
            let phase = Double(i % 30) / 30.0
            samples.append(UsageSample(t: t, session: 8 + phase * 58, weekly: 17, opus: 41, sonnet: 3))
        }
        var dayPeaks: [DayPeak] = []
        let f = DateFormatter(); f.locale = Locale(identifier: "en_US_POSIX"); f.dateFormat = "yyyy-MM-dd"
        for d in 0..<35 {
            guard let day = cal.date(byAdding: .day, value: -d, to: now) else { continue }
            // A natural-looking, non repeating curve.
            let base = 38 + 30 * sin(Double(d) * 0.55) + Double((d * 17) % 23) - 11
            let wk = min(96, max(4, base))
            dayPeaks.append(DayPeak(day: f.string(from: day), session: max(2, wk * 0.85), weekly: wk))
        }
        return UsageHistory(samples: samples, dayPeaks: dayPeaks)
    }
}
