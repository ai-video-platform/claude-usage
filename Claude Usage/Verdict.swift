//
//  Verdict.swift
//  Claude Usage
//
//  Turns the live limits into one plain language headline that names the binding
//  constraint and the pace. Calm is the default; urgent states stand out gently.
//

import SwiftUI
import HeadroomCore

struct Verdict {
    enum Level { case calm, caution, danger }

    var level: Level
    var icon: String
    /// Primary sentence, rendered in ink.
    var primary: String
    /// Trailing phrase, rendered in the level color when emphasized, else secondary.
    var detail: String
    var detailEmphasized: Bool
    var actionHint: String?

    var color: Color {
        switch level {
        case .calm: return Theme.healthSafe
        case .caution: return Theme.healthCaution
        case .danger: return Theme.healthDanger
        }
    }

    /// Build a verdict from live limits, or nil when there are no usable windows.
    static func make(_ live: LiveLimits) -> Verdict? {
        struct W { let name: String; let used: Double; let resetsAt: Date?; let window: TimeInterval; let isModel: Bool }
        var windows: [W] = []
        if let s = live.fiveHour { windows.append(W(name: "Session", used: s.usedPercent, resetsAt: s.resetsAt, window: UsageWindow.session, isModel: false)) }
        if let w = live.sevenDay { windows.append(W(name: "Weekly", used: w.usedPercent, resetsAt: w.resetsAt, window: UsageWindow.weekly, isModel: false)) }
        for m in (live.weeklyByModel ?? []) {
            windows.append(W(name: m.name, used: m.window.usedPercent, resetsAt: m.window.resetsAt, window: UsageWindow.weekly, isModel: true))
        }
        guard let binding = windows.max(by: { $0.used < $1.used }) else { return nil }

        let weeklyReset = live.sevenDay?.resetsAt
        let pct = Int(binding.used.rounded())

        // Suggest the least used model to switch to, when a model is the constraint.
        func switchHint() -> String? {
            guard binding.isModel else { return nil }
            let others = (live.weeklyByModel ?? []).filter { $0.name != binding.name }
            guard let cheapest = others.min(by: { $0.window.usedPercent < $1.window.usedPercent }),
                  cheapest.window.usedPercent < binding.used - 20 else { return nil }
            return "Consider switching to \(cheapest.name) to make it last."
        }

        // Already at the limit.
        if binding.used >= 99.5 {
            return Verdict(level: .danger, icon: "exclamationmark.octagon.fill",
                           primary: "\(binding.name) limit reached. ",
                           detail: "Full access returns \(Fmt.untilLong(binding.resetsAt)).",
                           detailEmphasized: false, actionHint: nil)
        }
        // Nearly used up.
        if binding.used >= 90 {
            return Verdict(level: .danger, icon: "exclamationmark.triangle.fill",
                           primary: "\(binding.name) is nearly used up, ",
                           detail: "\(pct)% used.",
                           detailEmphasized: true,
                           actionHint: switchHint())
        }

        // A model sub limit is tightest, even below 90, since these are the scarce ones.
        if binding.isModel, binding.used >= 70 {
            return Verdict(level: .caution, icon: "gauge.with.dots.needle.bottom.50percent",
                           primary: "\(binding.name) is your tightest limit, ",
                           detail: "\(pct)% used.",
                           detailEmphasized: true,
                           actionHint: switchHint())
        }

        // Over pace, project where the current burn lands.
        let overPace = (Pace.ratio(usedPercent: binding.used, resetsAt: binding.resetsAt, window: binding.window) ?? 0) > 1.15
        if binding.used >= 70 || (overPace && binding.used >= 45) {
            if let exhaust = Pace.projectedExhaustion(usedPercent: binding.used, resetsAt: binding.resetsAt, window: binding.window) {
                return Verdict(level: .caution, icon: "chart.line.uptrend.xyaxis",
                               primary: "At this pace you will hit your \(binding.name.lowercased()) limit ",
                               detail: "\(Fmt.whenHour(exhaust)).",
                               detailEmphasized: true, actionHint: nil)
            }
            return Verdict(level: .caution, icon: "exclamationmark.triangle.fill",
                           primary: "\(binding.name) is running high, ",
                           detail: "\(pct)% used.",
                           detailEmphasized: true, actionHint: nil)
        }

        // Calm default.
        return Verdict(level: .calm, icon: "checkmark.circle.fill",
                       primary: "You are on track. ",
                       detail: "Weekly resets \(Fmt.untilLong(weeklyReset)).",
                       detailEmphasized: false, actionHint: nil)
    }
}

/// The verdict rendered as a glass capsule for the dashboard and popover.
struct VerdictCapsule: View {
    let verdict: Verdict

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: verdict.icon)
                    .font(.subheadline).foregroundStyle(verdict.color)
                    .padding(.top, 1)
                (
                    Text(verdict.primary).foregroundStyle(Theme.ink)
                    + Text(verdict.detail).foregroundStyle(verdict.detailEmphasized ? verdict.color : Theme.inkSecondary)
                )
                .font(.subheadline.weight(.medium))
                .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            }
            if let hint = verdict.actionHint {
                Label(hint, systemImage: "arrow.triangle.2.circlepath")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(Theme.accent)
                    .padding(.horizontal, 10).padding(.vertical, 6)
                    .background(Theme.accent.opacity(0.14), in: .capsule)
                    .padding(.leading, 20)
            }
        }
        .padding(12)
        .background(verdict.color.opacity(0.12), in: .rect(cornerRadius: Theme.cornerTile))
        .accessibilityElement(children: .combine)
    }
}
