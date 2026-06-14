//
//  Gallery.swift
//  Claude Usage
//
//  A reference sheet of the current widget and menu bar designs, rendered with
//  demo data. Used to produce design reference screenshots. Reachable only with
//  the CU_SCREEN launch environment variable, never in normal use.
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
                    section("Widget · Large") { largeWidget }
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

    // MARK: Layout helpers

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
            VStack(spacing: 6) {
                UsageRing(title: "Session", percent: live.fiveHour?.usedPercent,
                          resetsAt: live.fiveHour?.resetsAt, window: UsageWindow.session,
                          diameter: 84, lineWidth: 9, showReset: false)
                Text(Fmt.countdown(to: live.fiveHour?.resetsAt))
                    .font(.system(size: 10)).foregroundStyle(.white.opacity(0.6))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var mediumWidget: some View {
        widgetSurface(338, 158) {
            HStack(spacing: 16) {
                UsageRing(title: "Session", percent: live.fiveHour?.usedPercent,
                          resetsAt: live.fiveHour?.resetsAt, window: UsageWindow.session,
                          diameter: 70, lineWidth: 8, showReset: false)
                UsageRing(title: "Weekly", percent: live.sevenDay?.usedPercent,
                          resetsAt: live.sevenDay?.resetsAt, window: UsageWindow.weekly,
                          diameter: 70, lineWidth: 8, showReset: false)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Claude Usage").font(.headline)
                    ForEach((live.weeklyByModel ?? []).prefix(2), id: \.name) { m in
                        HStack(spacing: 5) {
                            Circle().fill(Theme.health(m.window.usedPercent)).frame(width: 6, height: 6)
                            Text("\(m.name) \(Int(m.window.usedPercent.rounded()))%")
                                .font(.caption).foregroundStyle(.white.opacity(0.85))
                        }
                    }
                    Text(Fmt.countdown(to: live.sevenDay?.resetsAt))
                        .font(.caption2).foregroundStyle(.white.opacity(0.5))
                }
                Spacer(minLength: 0)
            }
            .frame(maxHeight: .infinity)
        }
    }

    private var largeWidget: some View {
        widgetSurface(338, 354) {
            VStack(alignment: .leading, spacing: 14) {
                Text("Claude Usage").font(.headline)
                Label("You are on track. Weekly resets in 2 days.", systemImage: "checkmark.circle.fill")
                    .font(.caption).foregroundStyle(Theme.healthSafe)
                HStack(spacing: 18) {
                    UsageRing(title: "Session", percent: live.fiveHour?.usedPercent,
                              resetsAt: live.fiveHour?.resetsAt, window: UsageWindow.session,
                              diameter: 88, lineWidth: 9, showReset: false)
                    UsageRing(title: "Weekly", percent: live.sevenDay?.usedPercent,
                              resetsAt: live.sevenDay?.resetsAt, window: UsageWindow.weekly,
                              diameter: 88, lineWidth: 9, showReset: false)
                    Spacer()
                }
                ForEach((live.weeklyByModel ?? []).prefix(3), id: \.name) { m in
                    UsageBar(label: m.name, percent: m.window.usedPercent,
                             resetsAt: m.window.resetsAt, window: UsageWindow.weekly, showPace: false)
                }
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: Lock Screen (accessory, monochrome)

    private var lockCircular: some View {
        ZStack {
            Circle().stroke(.white.opacity(0.25), lineWidth: 6)
            Circle().trim(from: 0, to: (live.fiveHour?.usedPercent ?? 0) / 100)
                .stroke(.white, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                .rotationEffect(.degrees(-90))
            VStack(spacing: 0) {
                Text("\(Int((live.fiveHour?.usedPercent ?? 0).rounded()))").font(.headline.bold())
                Text("5h").font(.system(size: 9))
            }.foregroundStyle(.white)
        }
        .frame(width: 64, height: 64)
    }

    private var lockRectangular: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Claude Usage").font(.caption.weight(.semibold))
            Text("Session \(p(live.fiveHour?.usedPercent))   Weekly \(p(live.sevenDay?.usedPercent))").font(.caption2)
            Text(Fmt.countdown(to: live.fiveHour?.resetsAt)).font(.caption2).foregroundStyle(.white.opacity(0.6))
        }
        .foregroundStyle(.white)
        .padding(12)
        .background(.white.opacity(0.08), in: .rect(cornerRadius: 12))
    }

    private var lockInline: some View {
        Label("Claude 5h \(p(live.fiveHour?.usedPercent)) · wk \(p(live.sevenDay?.usedPercent))",
              systemImage: "gauge.with.dots.needle.bottom.50percent")
            .font(.subheadline).foregroundStyle(.white)
    }

    // MARK: Menu bar styles

    private var menuBarStrip: some View {
        let s = live.fiveHour?.usedPercent ?? 0
        let reset = live.fiveHour?.resetsAt
        let w = live.sevenDay?.usedPercent ?? 0
        return VStack(spacing: 8) {
            menuRow("Percentage") { Text("\(p2(s))").foregroundStyle(Theme.health(s)) }
            menuRow("Percentage and time left") {
                HStack(spacing: 4) { Text("\(p2(s))").foregroundStyle(Theme.health(s)); Text(short(reset)).foregroundStyle(.secondary) }
            }
            menuRow("Time left") { HStack(spacing: 3) { Image(systemName: "clock"); Text(short(reset)) }.foregroundStyle(Theme.health(s)) }
            menuRow("Credits left") { Text("$1.61") }
            menuRow("Ring and percentage") {
                HStack(spacing: 4) {
                    ZStack {
                        Circle().stroke(.secondary.opacity(0.3), lineWidth: 2.5)
                        Circle().trim(from: 0, to: s / 100).stroke(Theme.health(s), style: StrokeStyle(lineWidth: 2.5, lineCap: .round)).rotationEffect(.degrees(-90))
                    }.frame(width: 12, height: 12)
                    Text("\(p2(s))").foregroundStyle(Theme.health(s))
                }
            }
            menuRow("Session and weekly") {
                HStack(spacing: 6) { Text("S \(p2(s))").foregroundStyle(Theme.health(s)); Text("W \(p2(w))").foregroundStyle(Theme.health(w)) }
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

    private func p(_ v: Double?) -> String { v.map { "\(Int($0.rounded()))%" } ?? "—" }
    private func p2(_ v: Double) -> String { "\(Int(v.rounded()))%" }
    private func short(_ d: Date?) -> String {
        guard let d else { return "—" }
        let s = max(0, d.timeIntervalSinceNow)
        let day = Int(s) / 86_400, h = (Int(s) % 86_400) / 3_600, m = (Int(s) % 3_600) / 60
        if day >= 1 { return "\(day)d" }
        if h >= 1 { return "\(h)h" }
        return "\(max(1, m))m"
    }
}
