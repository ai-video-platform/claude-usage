import Foundation

/// One recorded reading of the live limits. Kept as a private, on device time
/// series so History and the activity grid can show trends over time.
public struct UsageSample: Codable, Sendable {
    public var t: Date
    public var session: Double?
    public var weekly: Double?
    public var opus: Double?
    public var sonnet: Double?
    public init(t: Date, session: Double?, weekly: Double?, opus: Double?, sonnet: Double?) {
        self.t = t; self.session = session; self.weekly = weekly; self.opus = opus; self.sonnet = sonnet
    }
}

/// The highest utilization seen on a given calendar day, for the year activity grid.
public struct DayPeak: Codable, Sendable {
    public var day: String   // yyyy-MM-dd in the local calendar
    public var session: Double
    public var weekly: Double
    public init(day: String, session: Double, weekly: Double) {
        self.day = day; self.session = session; self.weekly = weekly
    }
}

public struct UsageHistory: Codable, Sendable {
    public var samples: [UsageSample]
    public var dayPeaks: [DayPeak]
    public init(samples: [UsageSample] = [], dayPeaks: [DayPeak] = []) {
        self.samples = samples; self.dayPeaks = dayPeaks
    }
    public var isEmpty: Bool { samples.isEmpty && dayPeaks.isEmpty }
}

/// Reads and writes the local usage time series in the shared container.
public enum HistoryStore {
    /// Keep fine grained samples for this long; the day peaks cover the year.
    static let sampleRetention: TimeInterval = 30 * 86_400
    static let dayPeakRetention: TimeInterval = 366 * 86_400
    /// Collapse bursts (manual plus auto refresh) into one point.
    static let minSampleGap: TimeInterval = 90

    static var url: URL { SupportDir.url.appendingPathComponent("history.json") }

    static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar.current
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    public static func load() -> UsageHistory {
        guard let data = try? Data(contentsOf: url),
              let h = try? HeadroomJSON.decoder.decode(UsageHistory.self, from: data) else {
            return UsageHistory()
        }
        return h
    }

    public static func save(_ h: UsageHistory) {
        SupportDir.ensure()
        if let data = try? HeadroomJSON.encoder.encode(h) {
            try? data.write(to: url)
        }
    }

    /// Append a reading, collapse bursts, refresh today's peak, and prune old data.
    public static func record(session: Double?, weekly: Double?, opus: Double?, sonnet: Double?,
                              now: Date = Date()) {
        var h = load()
        let sample = UsageSample(t: now, session: session, weekly: weekly, opus: opus, sonnet: sonnet)
        if let last = h.samples.last, now.timeIntervalSince(last.t) < minSampleGap {
            h.samples[h.samples.count - 1] = sample
        } else {
            h.samples.append(sample)
        }
        h.samples.removeAll { now.timeIntervalSince($0.t) > sampleRetention }

        // Update today's peak.
        let key = dayFormatter.string(from: now)
        let s = session ?? 0, w = weekly ?? 0
        if let idx = h.dayPeaks.firstIndex(where: { $0.day == key }) {
            h.dayPeaks[idx].session = max(h.dayPeaks[idx].session, s)
            h.dayPeaks[idx].weekly = max(h.dayPeaks[idx].weekly, w)
        } else {
            h.dayPeaks.append(DayPeak(day: key, session: s, weekly: w))
        }
        let cutoff = now.addingTimeInterval(-dayPeakRetention)
        h.dayPeaks.removeAll {
            guard let d = dayFormatter.date(from: $0.day) else { return false }
            return d < cutoff
        }

        save(h)
    }
}
