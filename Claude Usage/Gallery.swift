//
//  Gallery.swift
//  Claude Usage
//
//  A reference sheet of the current widget and menu bar designs (horizontal bars,
//  session first, reset highlighted), rendered with demo data for screenshots.
//  Reachable only with the CU_SCREEN launch environment variable.
//

import SwiftUI
import HeadroomCore

struct GalleryView: View {
    var page = 0
    private let live = DemoData.snapshot.live!

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                if page == 0 {
                    section("Menu bar styles (session first)") { menuBarStrip }
                    section("Widget · Small") { HStack(spacing: 16) { smallWidget; lockCircular } }
                    section("Widget · Medium") { mediumWidget }
                } else {
                    section("Lock Screen · Rectangular") { lockRectangular }
                    section("Lock Screen · Inline") { lockInline }
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(wallpaper)
        .preferredColorScheme(.dark)
    }

    private func section<Content: View>(_ title: String, @ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title.uppercased()).font(.caption.weight(.semibold)).tracking(0.6)
                .foregroundStyle(.white.opacity(0.6))
            content()
        }
    }

    private func widgetSurface<Content: View>(_ w: CGFloat, _ h: CGFloat, @ViewBuilder _ content: () -> Content) -> some View {
        content()
            .padding(14)
            .frame(width: w, height: h, alignment: .topLeading)
            .background(.regularMaterial, in: .rect(cornerRadius: 22))
    }

    private var wallpaper: some View {
        LinearGradient(colors: [Color(red: 0.20, green: 0.16, blue: 0.28),
                                Color(red: 0.10, green: 0.12, blue: 0.20),
                                Color(red: 0.06, green: 0.08, blue: 0.10)],
                       startPoint: .topLeading, endPoint: .bottomTrailing)
            .ignoresSafeArea()
    }

    // MARK: Widgets

    private var smallWidget: some View {
        widgetSurface(158, 158) {
            VStack(alignment: .leading, spacing: 8) {
                Label("Claude Usage", systemImage: "gauge.with.dots.needle.bottom.50percent")
                    .font(.caption2.weight(.semibold)).foregroundStyle(.secondary).labelStyle(.titleAndIcon)
                Spacer(minLength: 0)
                Text("SESSION").font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
                Text("\(pctI(live.fiveHour?.usedPercent))%")
                    .font(.system(size: 34, weight: .bold, design: .rounded)).monospacedDigit()
                Gauge(value: live.fiveHour?.usedPercent ?? 0, in: 0...100) { EmptyView() }
                    .gaugeStyle(.accessoryLinearCapacity).tint(Theme.health(live.fiveHour?.usedPercent ?? 0))
                ResetPill(date: live.fiveHour?.resetsAt ?? .now, color: Theme.health(live.fiveHour?.usedPercent ?? 0))
            }
        }
    }

    private var mediumWidget: some View {
        widgetSurface(338, 158) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Label("Claude Usage", systemImage: "gauge.with.dots.needle.bottom.50percent")
                        .font(.caption.weight(.semibold)).labelStyle(.titleAndIcon)
                    Spacer()
                    Label("On track", systemImage: "checkmark.circle.fill")
                        .font(.caption2).foregroundStyle(Theme.healthSafe)
                }
                MetricBar(label: "Session", percent: live.fiveHour?.usedPercent, resetsAt: live.fiveHour?.resetsAt, showReset: true)
                MetricBar(label: "Weekly", percent: live.sevenDay?.usedPercent)
                HStack(spacing: 14) {
                    ForEach((live.weeklyByModel ?? []).prefix(3), id: \.name) { m in
                        Text("\(m.name) \(pctI(m.window.usedPercent))%").font(.caption2).foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private var largeWidget: some View {
        widgetSurface(338, 354) {
            VStack(alignment: .leading, spacing: 14) {
                Label("Claude Usage", systemImage: "gauge.with.dots.needle.bottom.50percent")
                    .font(.headline).labelStyle(.titleAndIcon)
                Label("You are on track. Weekly resets in 2 days.", systemImage: "checkmark.circle.fill")
                    .font(.caption).foregroundStyle(Theme.healthSafe)
                MetricBar(label: "Session", percent: live.fiveHour?.usedPercent, resetsAt: live.fiveHour?.resetsAt, showReset: true)
                MetricBar(label: "Weekly", percent: live.sevenDay?.usedPercent, resetsAt: live.sevenDay?.resetsAt, showReset: true)
                ForEach((live.weeklyByModel ?? []).prefix(2), id: \.name) { m in
                    MetricBar(label: m.name, percent: m.window.usedPercent, dotColor: Theme.health(m.window.usedPercent))
                }
                Spacer(minLength: 0)
            }
        }
    }

    // MARK: Lock Screen (accessory)

    private var lockCircular: some View {
        Gauge(value: live.fiveHour?.usedPercent ?? 0, in: 0...100) {
            Text("5h")
        } currentValueLabel: {
            Text("\(pctI(live.fiveHour?.usedPercent))")
        }
        .gaugeStyle(.accessoryCircularCapacity)
        .frame(width: 64, height: 64)
        .tint(.white)
    }

    private var lockRectangular: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Claude · Session \(pctI(live.fiveHour?.usedPercent))%").font(.caption.weight(.semibold))
            Gauge(value: live.fiveHour?.usedPercent ?? 0, in: 0...100) { EmptyView() }
                .gaugeStyle(.accessoryLinearCapacity).tint(.white)
            Text(Fmt.countdown(to: live.fiveHour?.resetsAt)).font(.caption2).foregroundStyle(.secondary)
        }
        .foregroundStyle(.white)
        .padding(12)
        .frame(width: 240, alignment: .leading)
        .background(.white.opacity(0.08), in: .rect(cornerRadius: 12))
    }

    private var lockInline: some View {
        Label("Claude 5h \(pctI(live.fiveHour?.usedPercent))% · wk \(pctI(live.sevenDay?.usedPercent))%",
              systemImage: "clock").font(.subheadline).foregroundStyle(.white)
    }

    // MARK: Menu bar styles

    private var menuBarStrip: some View {
        let s = live.fiveHour?.usedPercent ?? 0
        let reset = live.fiveHour?.resetsAt
        let w = live.sevenDay?.usedPercent ?? 0
        return VStack(spacing: 8) {
            menuRow("Percentage and time left (default)") {
                HStack(spacing: 4) { Text("\(pctI(s))%").foregroundStyle(Theme.health(s)); Text("· \(short(reset))").foregroundStyle(.secondary) }
            }
            menuRow("Percentage") { Text("\(pctI(s))%").foregroundStyle(Theme.health(s)) }
            menuRow("Time left") { HStack(spacing: 3) { Image(systemName: "clock"); Text(short(reset)) }.foregroundStyle(Theme.health(s)) }
            menuRow("Credits left") { Text("$1.61") }
            menuRow("Session and weekly") {
                HStack(spacing: 6) { Text("S \(pctI(s))%").foregroundStyle(Theme.health(s)); Text("W \(pctI(w))%").foregroundStyle(Theme.health(w)) }
            }
        }
    }

    private func menuRow<Content: View>(_ name: String, @ViewBuilder _ chip: () -> Content) -> some View {
        HStack {
            Text(name).font(.subheadline).foregroundStyle(.white.opacity(0.8))
            Spacer()
            chip()
                .font(.system(size: 13, weight: .medium))
                .padding(.horizontal, 10).padding(.vertical, 5)
                .background(.black.opacity(0.5), in: .capsule)
        }
    }

    private func pctI(_ v: Double?) -> Int { Int((v ?? 0).rounded()) }
    private func short(_ d: Date?) -> String {
        guard let d else { return "now" }
        let s = max(0, d.timeIntervalSinceNow)
        let day = Int(s) / 86_400, h = (Int(s) % 86_400) / 3_600, m = (Int(s) % 3_600) / 60
        if day >= 1 { return "\(day)d \(h)h" }
        if h >= 1 { return "\(h)h \(m)m" }
        return "\(max(1, m))m"
    }
}
