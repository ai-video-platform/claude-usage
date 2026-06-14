//
//  HistoryView.swift
//  Claude Usage
//
//  Trends over time, built from the private on device time series (HistoryStore).
//  Until there is enough of it, we show an honest "still building" state.
//

import SwiftUI
import Charts
import HeadroomCore

struct HistoryView: View {
    @Bindable var model: UsageModel
    @State private var range: HistoryRange = .d30
    @State private var history = UsageHistory()
    @State private var exportURL: URL?

    enum HistoryRange: String, CaseIterable, Identifiable {
        case h12 = "12h", h24 = "24h", d3 = "3d", d7 = "7d", d30 = "30d", d90 = "90d"
        var id: String { rawValue }
        var seconds: TimeInterval {
            switch self {
            case .h12: return 12 * 3_600
            case .h24: return 24 * 3_600
            case .d3: return 3 * 86_400
            case .d7: return 7 * 86_400
            case .d30: return 30 * 86_400
            case .d90: return 90 * 86_400
            }
        }
    }

    private var hasData: Bool { !history.dayPeaks.isEmpty || history.samples.count > 1 }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                if hasData {
                    Picker("Range", selection: $range) {
                        ForEach(HistoryRange.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented).labelsHidden()

                    chartsCard
                    summaryRow
                    activityCard
                } else {
                    earlyState
                }
            }
            .padding(16)
            .frame(maxWidth: 580)
            .frame(maxWidth: .infinity)
        }
        .background(Theme.background)
        .navigationTitle("History")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.large)
        #endif
        .toolbar {
            if let exportURL {
                ToolbarItem(placement: .primaryAction) {
                    ShareLink(item: exportURL) { Image(systemName: "square.and.arrow.up") }
                }
            }
        }
        .tint(Theme.accent)
        .preferredColorScheme(.dark)
        .task { await loadHistory() }
    }

    // MARK: Data

    private func loadHistory() async {
        let h: UsageHistory
        if let demo = model.demoHistory {
            h = demo
        } else {
            h = await Task.detached { HistoryStore.load() }.value
        }
        history = h
        if let data = try? HeadroomJSON.encoder.encode(h) {
            let url = FileManager.default.temporaryDirectory.appendingPathComponent("ClaudeUsageHistory.json")
            try? data.write(to: url)
            exportURL = url
        }
    }

    private var filteredSamples: [UsageSample] {
        let cutoff = Date().addingTimeInterval(-range.seconds)
        let inRange = history.samples.filter { $0.t >= cutoff }
        guard inRange.count > 320 else { return inRange }
        let stride = inRange.count / 300
        return inRange.enumerated().compactMap { $0.offset % stride == 0 ? $0.element : nil }
    }

    private var filteredDayPeaks: [DayPeak] {
        let cutoff = Date().addingTimeInterval(-range.seconds)
        return history.dayPeaks.filter { (dayDate($0.day) ?? .distantPast) >= cutoff }
            .sorted { $0.day < $1.day }
    }

    // MARK: Charts

    private var chartsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            CardCaption(text: "Session usage over time")
            Chart(filteredSamples, id: \.t) { s in
                LineMark(x: .value("Time", s.t), y: .value("Session", s.session ?? 0))
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(Theme.accent.gradient)
            }
            .chartYScale(domain: 0...100)
            .chartXAxis(.hidden)
            .chartYAxis { AxisMarks(position: .leading, values: [0, 50, 100]) { _ in
                AxisGridLine().foregroundStyle(.white.opacity(0.06))
                AxisValueLabel().foregroundStyle(Theme.inkTertiary)
            } }
            .frame(height: 130)

            CardCaption(text: "Peak weekly per day")
            Chart(filteredDayPeaks, id: \.day) { d in
                BarMark(x: .value("Day", d.day), y: .value("Peak", d.weekly))
                    .foregroundStyle(Theme.health(d.weekly))
                    .cornerRadius(3)
            }
            .chartYScale(domain: 0...100)
            .chartXAxis(.hidden)
            .chartYAxis { AxisMarks(position: .leading, values: [0, 50, 100]) { _ in
                AxisGridLine().foregroundStyle(.white.opacity(0.06))
                AxisValueLabel().foregroundStyle(Theme.inkTertiary)
            } }
            .frame(height: 120)
        }
        .glassCard(padding: 16)
    }

    private var summaryRow: some View {
        let peaks = filteredDayPeaks
        let avg = peaks.isEmpty ? 0 : peaks.map(\.weekly).reduce(0, +) / Double(peaks.count)
        let busiest = peaks.max(by: { $0.weekly < $1.weekly })
        return HStack(spacing: 12) {
            summaryTile("Avg weekly", "\(Int(avg.rounded()))%")
            summaryTile("Busiest day", busiest.map { weekdayName($0.day) } ?? "none")
            summaryTile("Weekly use", "\(Int(avg.rounded()))%")
        }
    }

    private func summaryTile(_ caption: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            CardCaption(text: caption)
            Text(value).font(.system(.title3, design: .rounded).weight(.semibold))
                .foregroundStyle(Theme.ink).minimumScaleFactor(0.7).lineLimit(1)
        }
        .glassCard(padding: 12)
    }

    private var activityCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                CardCaption(text: "Your last year")
                Spacer()
                Text("\(activeStreak()) day streak")
                    .font(.caption.weight(.medium)).foregroundStyle(Theme.accent)
            }
            ActivityGridView(dayPeaks: history.dayPeaks)
        }
        .glassCard(padding: 14)
    }

    // MARK: Early state

    private var earlyState: some View {
        VStack(alignment: .leading, spacing: 12) {
            RoundedRectangle(cornerRadius: Theme.cornerTile)
                .fill(.white.opacity(0.04)).frame(height: 140)
                .overlay(Image(systemName: "chart.bar.xaxis").font(.system(size: 34)).foregroundStyle(Theme.inkTertiary))
            Text("Keep the app running to build your history.")
                .font(.subheadline.weight(.medium)).foregroundStyle(Theme.ink)
            Text("Each refresh is saved on this device so you can see your usage trends and a year of activity over time. There is nothing here yet, that is normal on day one.")
                .font(.caption).foregroundStyle(Theme.inkSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .glassCard(padding: 16)
    }

    // MARK: Helpers

    private func activeStreak() -> Int {
        let map = Dictionary(uniqueKeysWithValues: history.dayPeaks.map { ($0.day, $0) })
        var count = 0
        var day = Date()
        for _ in 0..<366 {
            let key = HistoryView.dayKeyFormatter.string(from: day)
            if let p = map[key], (p.weekly > 0 || p.session > 0) { count += 1 } else { break }
            day = Calendar.current.date(byAdding: .day, value: -1, to: day) ?? day
        }
        return count
    }

    private func dayDate(_ s: String) -> Date? { HistoryView.dayKeyFormatter.date(from: s) }
    private func weekdayName(_ s: String) -> String {
        guard let d = dayDate(s) else { return "—" }
        let f = DateFormatter(); f.dateFormat = "EEEE"
        return f.string(from: d)
    }

    static let dayKeyFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()
}

/// A GitHub style year heat grid in the clay ramp.
struct ActivityGridView: View {
    let dayPeaks: [DayPeak]

    private var intensity: [String: Double] {
        Dictionary(uniqueKeysWithValues: dayPeaks.map { ($0.day, max($0.weekly, $0.session)) })
    }

    var body: some View {
        let weeks = buildWeeks()
        ScrollViewReader { _ in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 3) {
                    ForEach(Array(weeks.enumerated()), id: \.offset) { _, week in
                        VStack(spacing: 3) {
                            ForEach(0..<7, id: \.self) { row in
                                cell(week[row])
                            }
                        }
                    }
                }
            }
        }
        .overlay(alignment: .bottomTrailing) { legend.padding(.top, 6) }
    }

    @ViewBuilder private func cell(_ date: Date?) -> some View {
        let size: CGFloat = 11
        if let date {
            let key = HistoryView.dayKeyFormatter.string(from: date)
            let v = intensity[key]
            RoundedRectangle(cornerRadius: 2)
                .fill(color(for: v))
                .frame(width: size, height: size)
                .help(v != nil ? "\(key): \(Int(v!.rounded()))%" : key)
        } else {
            RoundedRectangle(cornerRadius: 2).fill(.clear).frame(width: size, height: size)
        }
    }

    private func color(for v: Double?) -> Color {
        guard let v, v > 0 else { return Color.white.opacity(0.05) }
        return Theme.accent.opacity(0.2 + 0.8 * min(1, v / 100))
    }

    private var legend: some View {
        HStack(spacing: 4) {
            Text("less").font(.caption2).foregroundStyle(Theme.inkTertiary)
            ForEach([0.0, 0.33, 0.66, 1.0], id: \.self) { f in
                RoundedRectangle(cornerRadius: 2)
                    .fill(f == 0 ? Color.white.opacity(0.05) : Theme.accent.opacity(0.2 + 0.8 * f))
                    .frame(width: 9, height: 9)
            }
            Text("more").font(.caption2).foregroundStyle(Theme.inkTertiary)
        }
    }

    private func buildWeeks() -> [[Date?]] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let thisWeekStart = cal.dateInterval(of: .weekOfYear, for: today)?.start ?? today
        let firstWeekStart = cal.date(byAdding: .weekOfYear, value: -51, to: thisWeekStart) ?? today
        var weeks: [[Date?]] = []
        var cursor = firstWeekStart
        for _ in 0...51 {
            var week: [Date?] = []
            for d in 0..<7 {
                let day = cal.date(byAdding: .day, value: d, to: cursor) ?? cursor
                week.append(day <= today ? day : nil)
            }
            weeks.append(week)
            cursor = cal.date(byAdding: .weekOfYear, value: 1, to: cursor) ?? cursor
        }
        return weeks
    }
}
