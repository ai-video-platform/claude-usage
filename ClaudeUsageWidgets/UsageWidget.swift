//
//  UsageWidget.swift
//  ClaudeUsageWidgets
//
//  Renders the shared UsageSnapshot. Data is written by the app into the App Group
//  container; the widget reads the latest snapshot (or sample on first run). A
//  stale snapshot is marked, never shown as a fresh number.
//

import WidgetKit
import SwiftUI
import HeadroomCore

// MARK: - Timeline

struct UsageEntry: TimelineEntry {
    let date: Date
    let snapshot: UsageSnapshot
}

struct UsageProvider: TimelineProvider {
    func placeholder(in context: Context) -> UsageEntry {
        UsageEntry(date: Date(), snapshot: .sample)
    }
    func getSnapshot(in context: Context, completion: @escaping (UsageEntry) -> Void) {
        completion(currentEntry())
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<UsageEntry>) -> Void) {
        let next = Date().addingTimeInterval(15 * 60)
        completion(Timeline(entries: [currentEntry()], policy: .after(next)))
    }
    private func currentEntry() -> UsageEntry {
        UsageEntry(date: Date(), snapshot: SnapshotStore.load() ?? .sample)
    }
}

// MARK: - Widget

struct UsageWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "ClaudeUsageWidget", provider: UsageProvider()) { entry in
            UsageWidgetView(entry: entry)
                .modifier(WidgetBackground())
        }
        .configurationDisplayName("Claude Usage")
        .description("Your Claude weekly and 5 hour limits at a glance.")
        .supportedFamilies(Self.families)
    }

    static var families: [WidgetFamily] {
        #if os(iOS)
        return [.systemSmall, .systemMedium, .systemLarge, .accessoryCircular, .accessoryRectangular, .accessoryInline]
        #else
        return [.systemSmall, .systemMedium, .systemLarge]
        #endif
    }
}

// MARK: - Constants and helpers (widget target is separate from the app target)

private enum W {
    static let session: TimeInterval = 5 * 3_600
    static let weekly: TimeInterval = 7 * 86_400
    static let safe = Color(red: 0.31, green: 0.827, blue: 0.494)
    static let caution = Color(red: 1.0, green: 0.722, blue: 0.302)
    static let danger = Color(red: 1.0, green: 0.42, blue: 0.42)
    static let accent = Color(red: 0.851, green: 0.467, blue: 0.341)

    static func color(_ p: Double) -> Color {
        switch p { case ..<70: return safe; case ..<90: return caution; default: return danger }
    }
    static func paceFraction(_ resetsAt: Date?, _ window: TimeInterval) -> Double? {
        guard let resetsAt else { return nil }
        return min(1, max(0, 1 - resetsAt.timeIntervalSinceNow / window))
    }
    static func isStale(_ date: Date) -> Bool { Date().timeIntervalSince(date) > 30 * 60 }
}

// MARK: - Background

/// Accessory (Lock Screen / StandBy) families are transparent; home screen families
/// get a frosted glass surface so the wallpaper shows through (Liquid Glass).
struct WidgetBackground: ViewModifier {
    @Environment(\.widgetFamily) private var family
    func body(content: Content) -> some View {
        #if os(iOS)
        switch family {
        case .accessoryCircular, .accessoryRectangular, .accessoryInline:
            content.containerBackground(.clear, for: .widget)
        default:
            content.containerBackground(.regularMaterial, for: .widget)
        }
        #else
        content.containerBackground(.regularMaterial, for: .widget)
        #endif
    }
}

// MARK: - Router

struct UsageWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: UsageEntry

    var body: some View {
        switch family {
        case .systemSmall: SmallUsageView(entry: entry)
        case .systemMedium: MediumUsageView(entry: entry)
        case .systemLarge: LargeUsageView(entry: entry)
        #if os(iOS)
        case .accessoryCircular: AccessoryCircularView(entry: entry)
        case .accessoryRectangular: AccessoryRectangularView(entry: entry)
        case .accessoryInline: AccessoryInlineView(entry: entry)
        #endif
        default: MediumUsageView(entry: entry)
        }
    }
}

// MARK: - Ring

struct WidgetRing: View {
    let title: String
    let percent: Double?
    var resetsAt: Date? = nil
    var window: TimeInterval = W.weekly
    var showPace: Bool = true
    var lineWidth: CGFloat = 8

    var body: some View {
        GeometryReader { geo in
            let d = min(geo.size.width, geo.size.height)
            ZStack {
                Circle().stroke(.primary.opacity(0.15), lineWidth: lineWidth)
                if let p = percent {
                    Circle().trim(from: 0, to: min(1, p / 100))
                        .stroke(W.color(p), style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    if showPace, let frac = W.paceFraction(resetsAt, window) {
                        Capsule().fill(.primary.opacity(0.7))
                            .frame(width: 2, height: lineWidth + 5)
                            .offset(y: -(d / 2 - lineWidth / 2))
                            .rotationEffect(.degrees(frac * 360))
                    }
                }
                VStack(spacing: 0) {
                    Text(percent.map { "\(Int($0.rounded()))%" } ?? "··")
                        .font(.system(size: d * 0.22, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                    Text(title).font(.system(size: max(8, d * 0.085), weight: .semibold))
                        .foregroundStyle(.primary.opacity(0.55))
                }
            }
        }
    }
}

// MARK: - System families

struct SmallUsageView: View {
    let entry: UsageEntry
    var body: some View {
        let live = entry.snapshot.live
        VStack(spacing: 6) {
            WidgetRing(title: "SESSION", percent: live?.fiveHour?.usedPercent,
                       resetsAt: live?.fiveHour?.resetsAt, window: W.session)
                .frame(width: 86, height: 86)
            Text(reset(live?.fiveHour?.resetsAt))
                .font(.system(size: 10)).foregroundStyle(.primary.opacity(0.6))
        }
    }
}

struct MediumUsageView: View {
    let entry: UsageEntry
    var body: some View {
        let live = entry.snapshot.live
        HStack(spacing: 16) {
            WidgetRing(title: "SESSION", percent: live?.fiveHour?.usedPercent,
                       resetsAt: live?.fiveHour?.resetsAt, window: W.session).frame(width: 74, height: 74)
            WidgetRing(title: "WEEKLY", percent: live?.sevenDay?.usedPercent,
                       resetsAt: live?.sevenDay?.resetsAt, window: W.weekly).frame(width: 74, height: 74)
            VStack(alignment: .leading, spacing: 3) {
                Text("Claude Usage").font(.headline).foregroundStyle(.primary)
                ForEach((live?.weeklyByModel ?? []).prefix(2), id: \.name) { m in
                    modelLine(m.name, m.window.usedPercent)
                }
                Text(reset(live?.sevenDay?.resetsAt)).font(.caption2).foregroundStyle(.primary.opacity(0.4))
            }
            Spacer(minLength: 0)
        }
    }
    private func modelLine(_ name: String, _ pct: Double) -> some View {
        HStack(spacing: 5) {
            Circle().fill(W.color(pct)).frame(width: 6, height: 6)
            Text("\(name) \(Int(pct.rounded()))%").font(.caption).foregroundStyle(.primary.opacity(0.8))
        }
    }
}

struct LargeUsageView: View {
    let entry: UsageEntry
    var body: some View {
        let live = entry.snapshot.live
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Claude Usage").font(.headline).foregroundStyle(.primary)
                Spacer()
                if W.isStale(entry.snapshot.generatedAt) {
                    Image(systemName: "clock.badge.exclamationmark").font(.caption2).foregroundStyle(.primary.opacity(0.5))
                }
            }
            statusLine(live)
            HStack(spacing: 18) {
                WidgetRing(title: "SESSION", percent: live?.fiveHour?.usedPercent,
                           resetsAt: live?.fiveHour?.resetsAt, window: W.session).frame(width: 80, height: 80)
                WidgetRing(title: "WEEKLY", percent: live?.sevenDay?.usedPercent,
                           resetsAt: live?.sevenDay?.resetsAt, window: W.weekly).frame(width: 80, height: 80)
                Spacer()
            }
            ForEach((live?.weeklyByModel ?? []).prefix(3), id: \.name) { m in
                bar(m.name, m.window.usedPercent)
            }
            Spacer(minLength: 0)
        }
    }

    @ViewBuilder private func statusLine(_ live: LiveLimits?) -> some View {
        let maxPct = [live?.sevenDay?.usedPercent, live?.fiveHour?.usedPercent, live?.sevenDayOpus?.usedPercent]
            .compactMap { $0 }.max() ?? 0
        let (icon, text, color): (String, String, Color) = {
            if maxPct >= 90 { return ("exclamationmark.triangle.fill", "Running high", W.danger) }
            if maxPct >= 70 { return ("exclamationmark.circle.fill", "Getting close", W.caution) }
            return ("checkmark.circle.fill", "You are on track", W.safe)
        }()
        HStack(spacing: 6) {
            Image(systemName: icon).foregroundStyle(color)
            Text(text).foregroundStyle(.primary.opacity(0.85))
            Text(reset(live?.sevenDay?.resetsAt)).foregroundStyle(.primary.opacity(0.4))
        }
        .font(.caption)
    }

    private func bar(_ name: String, _ pct: Double) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text(name).font(.caption).foregroundStyle(.primary.opacity(0.8))
                Spacer()
                Text("\(Int(pct.rounded()))%").font(.caption.monospacedDigit()).foregroundStyle(.primary.opacity(0.6))
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(.primary.opacity(0.12))
                    Capsule().fill(W.color(pct)).frame(width: geo.size.width * min(1, pct / 100))
                }
            }
            .frame(height: 6)
        }
    }
}

// MARK: - Shared text helpers

private func reset(_ d: Date?) -> String {
    guard let d else { return "limits unavailable" }
    let s = max(0, d.timeIntervalSinceNow)
    let days = Int(s) / 86_400, hours = (Int(s) % 86_400) / 3_600
    return days > 0 ? "resets in \(days)d \(hours)h" : "resets in \(hours)h"
}
private func pct(_ p: Double?) -> String { p.map { "\(Int($0.rounded()))%" } ?? "··" }

// MARK: - Lock Screen / StandBy accessories

#if os(iOS)
struct AccessoryCircularView: View {
    let entry: UsageEntry
    var body: some View {
        if let p = entry.snapshot.live?.sevenDay?.usedPercent {
            Gauge(value: min(1, p / 100)) { Text("Wk") } currentValueLabel: { Text("\(Int(p.rounded()))") }
                .gaugeStyle(.accessoryCircularCapacity)
        } else {
            Image(systemName: "gauge.with.dots.needle.bottom.50percent")
        }
    }
}

struct AccessoryRectangularView: View {
    let entry: UsageEntry
    var body: some View {
        let live = entry.snapshot.live
        VStack(alignment: .leading, spacing: 2) {
            Text("Claude Usage").font(.caption.weight(.semibold))
            Text("Weekly \(pct(live?.sevenDay?.usedPercent))   5h \(pct(live?.fiveHour?.usedPercent))")
                .font(.caption2)
            Text(reset(live?.sevenDay?.resetsAt)).font(.caption2).foregroundStyle(.secondary)
        }
    }
}

struct AccessoryInlineView: View {
    let entry: UsageEntry
    var body: some View {
        let live = entry.snapshot.live
        Text("Claude wk \(pct(live?.sevenDay?.usedPercent)) · 5h \(pct(live?.fiveHour?.usedPercent))")
    }
}
#endif
