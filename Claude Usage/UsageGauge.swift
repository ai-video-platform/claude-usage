//
//  UsageGauge.swift
//  Claude Usage
//
//  The reusable gauge: ring and bar forms. Always shows percent USED (matching
//  claude.ai), health colored, with the signature pace marker (a tick at how far
//  through the time window you are). The gap between the fill and the pace tick is
//  the ahead or behind read.
//

import SwiftUI

/// A circular usage gauge with center percent used, window name, pace tick, and reset countdown.
struct UsageRing: View {
    let title: String
    let percent: Double?            // percent used; nil renders the loading state
    var resetsAt: Date? = nil
    var window: TimeInterval = UsageWindow.weekly
    var showPace: Bool = true
    var diameter: CGFloat = 124
    var lineWidth: CGFloat = 12
    var showReset: Bool = true

    private var used: Double { percent ?? 0 }
    private var color: Color { percent == nil ? Color.white.opacity(0.18) : Theme.health(used) }

    var body: some View {
        VStack(spacing: 10) {
            ZStack {
                Circle()
                    .stroke(.white.opacity(0.08), style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))

                if percent != nil {
                    Circle()
                        .trim(from: 0, to: min(1, used / 100))
                        .stroke(Theme.healthGradient(used), style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .shadow(color: color.opacity(0.45), radius: 6)
                        .animation(.snappy, value: used)
                }

                // Pace marker tick: how far through the window we are.
                if showPace, percent != nil,
                   let frac = Pace.elapsedFraction(resetsAt: resetsAt, window: window) {
                    Capsule()
                        .fill(Theme.pace)
                        .frame(width: 2.5, height: lineWidth + 7)
                        .offset(y: -(diameter / 2 - lineWidth / 2))
                        .rotationEffect(.degrees(frac * 360))
                }

                VStack(spacing: 1) {
                    if percent == nil {
                        Text("··")
                            .font(.system(size: diameter * 0.26, weight: .bold, design: .rounded))
                            .foregroundStyle(Theme.inkTertiary)
                    } else {
                        Text("\(Int(used.rounded()))%")
                            .font(.system(size: diameter * 0.24, weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(Theme.ink)
                            .contentTransition(.numericText())
                    }
                    Text(title.uppercased())
                        .font(.system(size: max(9, diameter * 0.075), weight: .semibold)).tracking(0.7)
                        .foregroundStyle(Theme.inkTertiary)
                }
            }
            .frame(width: diameter, height: diameter)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(title)
            .accessibilityValue(percent == nil ? "loading" : "\(Int(used.rounded())) percent used, \(Fmt.countdown(to: resetsAt))")

            if showReset {
                Text(percent == nil ? " " : Fmt.countdown(to: resetsAt))
                    .font(.caption).foregroundStyle(Theme.inkSecondary)
            }
        }
    }
}

/// A horizontal usage bar with label, percent used, pace tick, and an optional model dot.
struct UsageBar: View {
    let label: String
    let percent: Double?            // percent used
    var resetsAt: Date? = nil
    var window: TimeInterval = UsageWindow.weekly
    var showPace: Bool = true
    var dotColor: Color? = nil

    private var used: Double { percent ?? 0 }
    private var warn: Bool { used >= 90 }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                if let dotColor {
                    Circle().fill(dotColor).frame(width: 7, height: 7)
                }
                Text(label).font(.subheadline.weight(.medium)).foregroundStyle(Theme.ink)
                if warn {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.caption2).foregroundStyle(Theme.healthDanger)
                }
                Spacer()
                Text(percent == nil ? "··" : "\(Int(used.rounded()))%")
                    .font(.subheadline.monospacedDigit()).foregroundStyle(Theme.inkSecondary)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(.white.opacity(0.08))
                    if percent != nil {
                        Capsule().fill(Theme.health(used))
                            .frame(width: geo.size.width * min(1, used / 100))
                            .animation(.snappy, value: used)
                    }
                    if showPace, percent != nil,
                       let frac = Pace.elapsedFraction(resetsAt: resetsAt, window: window) {
                        Capsule().fill(Theme.pace)
                            .frame(width: 2, height: 12)
                            .offset(x: geo.size.width * frac - 1)
                    }
                }
            }
            .frame(height: 8)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
        .accessibilityValue(percent == nil ? "loading" : "\(Int(used.rounded())) percent used")
    }
}
