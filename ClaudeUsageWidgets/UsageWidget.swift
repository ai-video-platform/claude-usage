//
//  UsageWidget.swift
//  ClaudeUsageWidgets
//
//  Horizontal bars (battery/storage pattern), session first, reset highlighted.
//  No rings except the Lock Screen circular slot, which is circular by system
//  design. Reads the shared UsageSnapshot; a stale snapshot is marked.
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
    func placeholder(in context: Context) -> UsageEntry { UsageEntry(date: Date(), snapshot: .sample) }
    func getSnapshot(in context: Context, completion: @escaping (UsageEntry) -> Void) { completion(currentEntry()) }
    func getTimeline(in context: Context, completion: @escaping (Timeline<UsageEntry>) -> Void) {
        completion(Timeline(entries: [currentEntry()], policy: .after(Date().addingTimeInterval(15 * 60))))
    }
    private func currentEntry() -> UsageEntry { UsageEntry(date: Date(), snapshot: SnapshotStore.load() ?? .sample) }
}

// MARK: - Widget

struct UsageWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "ClaudeUsageWidget", provider: UsageProvider()) { entry in
            UsageWidgetView(entry: entry).modifier(WidgetBackground())
        }
        .configurationDisplayName("Claude Usage")
        .description("Your Claude session and weekly limits at a glance.")
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

// MARK: - Helpers

private enum W {
    static let session: TimeInterval = 5 * 3_600
    static let weekly: TimeInterval = 7 * 86_400
    static let safe = Color(red: 0.31, green: 0.827, blue: 0.494)
    static let caution = Color(red: 1.0, green: 0.722, blue: 0.302)
    static let danger = Color(red: 1.0, green: 0.42, blue: 0.42)
    static func color(_ p: Double) -> Color {
        switch p { case ..<70: return safe; case ..<90: return caution; default: return danger }
    }
    static func isStale(_ date: Date) -> Bool { Date().timeIntervalSince(date) > 30 * 60 }
}

private func pct(_ p: Double?) -> String { p.map { "\(Int($0.rounded()))%" } ?? "··" }

private func reset(_ d: Date?) -> String {
    guard let d else { return "resets time unknown" }
    let s = max(0, d.timeIntervalSinceNow)
    let days = Int(s) / 86_400, h = (Int(s) % 86_400) / 3_600, m = (Int(s) % 3_600) / 60
    if days > 0 { return "resets in \(days)d" }
    if h > 0 { return "resets in \(h)h \(m)m" }
    return "resets in \(m)m"
}
private func shortReset(_ d: Date?) -> String {
    guard let d else { return "" }
    let s = max(0, d.timeIntervalSinceNow)
    let days = Int(s) / 86_400, h = (Int(s) % 86_400) / 3_600, m = (Int(s) % 3_600) / 60
    if days > 0 { return "\(days)d" }
    if h > 0 { return "\(h)h" }
    return "\(max(1, m))m"
}

// MARK: - Background (frosted material so the wallpaper shows through)

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

// MARK: - Bar

struct WBar: View {
    let label: String
    let percent: Double?
    var dot: Bool = false
    var reset: Date? = nil          // shown inline after the percent
    private var used: Double { percent ?? 0 }
    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 5) {
                if dot { Circle().fill(W.color(used)).frame(width: 6, height: 6) }
                Text(label).font(.caption.weight(.medium)).foregroundStyle(.primary)
                Spacer()
                Text(reset == nil ? pct(percent) : "\(pct(percent)) · \(shortReset(reset))")
                    .font(.caption.weight(.semibold)).monospacedDigit()
                    .foregroundStyle(W.color(used))
            }
            Gauge(value: used, in: 0...100) { EmptyView() }
                .gaugeStyle(.accessoryLinearCapacity)
                .tint(W.color(used))
        }
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

private func titleRow(_ stale: Bool) -> some View {
    HStack(spacing: 4) {
        Image(systemName: "gauge.with.dots.needle.bottom.50percent").font(.caption2)
        Text("Claude Usage").font(.caption.weight(.semibold))
        if stale { Image(systemName: "clock.badge.exclamationmark").font(.caption2).foregroundStyle(.secondary) }
    }
    .foregroundStyle(.primary)
}

// MARK: - System families

struct SmallUsageView: View {
    let entry: UsageEntry
    var body: some View {
        let live = entry.snapshot.live
        let s = live?.fiveHour?.usedPercent ?? 0
        VStack(alignment: .leading, spacing: 6) {
            titleRow(W.isStale(entry.snapshot.generatedAt))
            Spacer(minLength: 0)
            Text("SESSION").font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
            Text(pct(live?.fiveHour?.usedPercent))
                .font(.system(size: 32, weight: .bold, design: .rounded)).monospacedDigit()
                .foregroundStyle(.primary)
            Gauge(value: s, in: 0...100) { EmptyView() }
                .gaugeStyle(.accessoryLinearCapacity).tint(W.color(s))
            Text(reset(live?.fiveHour?.resetsAt)).font(.caption2).foregroundStyle(W.color(s))
        }
    }
}

struct MediumUsageView: View {
    let entry: UsageEntry
    var body: some View {
        let live = entry.snapshot.live
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                titleRow(W.isStale(entry.snapshot.generatedAt))
                Spacer()
                verdictChip(live)
            }
            WBar(label: "Session", percent: live?.fiveHour?.usedPercent, reset: live?.fiveHour?.resetsAt)
            WBar(label: "Weekly", percent: live?.sevenDay?.usedPercent, reset: live?.sevenDay?.resetsAt)
            HStack(spacing: 12) {
                ForEach((live?.weeklyByModel ?? []).prefix(3), id: \.name) { m in
                    Text("\(m.name) \(pct(m.window.usedPercent))").font(.caption2).foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }
        }
    }
}

struct LargeUsageView: View {
    let entry: UsageEntry
    var body: some View {
        let live = entry.snapshot.live
        VStack(alignment: .leading, spacing: 12) {
            titleRow(W.isStale(entry.snapshot.generatedAt))
            verdictLine(live)
            WBar(label: "Session", percent: live?.fiveHour?.usedPercent, reset: live?.fiveHour?.resetsAt)
            WBar(label: "Weekly", percent: live?.sevenDay?.usedPercent, reset: live?.sevenDay?.resetsAt)
            ForEach((live?.weeklyByModel ?? []).prefix(3), id: \.name) { m in
                WBar(label: m.name, percent: m.window.usedPercent, dot: true)
            }
            Spacer(minLength: 0)
        }
    }
}

// Verdict helpers

private func maxUsed(_ live: LiveLimits?) -> Double {
    [live?.fiveHour?.usedPercent, live?.sevenDay?.usedPercent, live?.sevenDayOpus?.usedPercent]
        .compactMap { $0 }.max() ?? 0
}
private func verdictChip(_ live: LiveLimits?) -> some View {
    let m = maxUsed(live)
    let (icon, text, color): (String, String, Color) = m >= 90
        ? ("exclamationmark.triangle.fill", "High", W.danger)
        : (m >= 70 ? ("exclamationmark.circle.fill", "Close", W.caution) : ("checkmark.circle.fill", "On track", W.safe))
    return Label(text, systemImage: icon).font(.caption2).foregroundStyle(color)
}
private func verdictLine(_ live: LiveLimits?) -> some View {
    let m = maxUsed(live)
    let (icon, text, color): (String, String, Color) = m >= 90
        ? ("exclamationmark.triangle.fill", "A limit is nearly used up.", W.danger)
        : (m >= 70 ? ("exclamationmark.circle.fill", "Getting close to a limit.", W.caution) : ("checkmark.circle.fill", "You are on track.", W.safe))
    return Label(text, systemImage: icon).font(.caption).foregroundStyle(color)
}

// MARK: - Lock Screen / StandBy accessories

#if os(iOS)
struct AccessoryCircularView: View {
    let entry: UsageEntry
    var body: some View {
        if let p = entry.snapshot.live?.fiveHour?.usedPercent {
            Gauge(value: min(1, p / 100)) { Text("5h") } currentValueLabel: { Text("\(Int(p.rounded()))") }
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
            Text("Claude · Session \(pct(live?.fiveHour?.usedPercent))").font(.caption.weight(.semibold))
            Gauge(value: live?.fiveHour?.usedPercent ?? 0, in: 0...100) { EmptyView() }
                .gaugeStyle(.accessoryLinearCapacity)
            Text(reset(live?.fiveHour?.resetsAt)).font(.caption2).foregroundStyle(.secondary)
        }
    }
}

struct AccessoryInlineView: View {
    let entry: UsageEntry
    var body: some View {
        let live = entry.snapshot.live
        Label("Claude 5h \(pct(live?.fiveHour?.usedPercent)) · wk \(pct(live?.sevenDay?.usedPercent))",
              systemImage: "clock")
    }
}
#endif
