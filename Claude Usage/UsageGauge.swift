//
//  UsageGauge.swift
//  Claude Usage
//
//  The metric display is a horizontal progress bar (the battery and storage
//  pattern from Settings): a label and percent used above, a health tinted linear
//  gauge, and, for the main windows, the reset countdown highlighted in a pill
//  right after the percent. No rings, no pace marker.
//

import SwiftUI

/// One usage metric as a horizontal bar.
struct MetricBar: View {
    let label: String
    let percent: Double?            // percent used; nil renders the loading state
    var resetsAt: Date? = nil
    var showReset: Bool = false
    var dotColor: Color? = nil

    private var used: Double { percent ?? 0 }
    private var color: Color { percent == nil ? Color.secondary : Theme.health(used) }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                if let dotColor { Circle().fill(dotColor).frame(width: 7, height: 7) }
                Text(label).font(.subheadline.weight(.medium)).foregroundStyle(Theme.ink)
                if percent != nil, used >= 90 {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.caption2).foregroundStyle(Theme.healthDanger)
                }
                Spacer()
                Text(percent == nil ? "··" : "\(Int(used.rounded()))%")
                    .font(.subheadline.weight(.semibold).monospacedDigit())
                    .foregroundStyle(color)
                    .contentTransition(.numericText())
            }

            Gauge(value: used, in: 0...100) { EmptyView() }
                .gaugeStyle(.accessoryLinearCapacity)
                .tint(color)
                .animation(.snappy, value: used)

            if showReset, let resetsAt {
                ResetPill(date: resetsAt, color: color)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
        .accessibilityValue(accessibilityValue)
    }

    private var accessibilityValue: String {
        guard percent != nil else { return "loading" }
        var v = "\(Int(used.rounded())) percent used"
        if showReset, resetsAt != nil { v += ", \(Fmt.countdown(to: resetsAt))" }
        return v
    }
}

/// A small clock plus reset countdown in a soft health colored pill. This is the
/// second thing the user reads, after the percent.
struct ResetPill: View {
    let date: Date
    var color: Color = .secondary
    var body: some View {
        Label(Fmt.countdown(to: date), systemImage: "clock")
            .font(.caption2.weight(.medium))
            .foregroundStyle(color)
            .padding(.horizontal, 8).padding(.vertical, 3)
            .background(color.opacity(0.15), in: .capsule)
    }
}
