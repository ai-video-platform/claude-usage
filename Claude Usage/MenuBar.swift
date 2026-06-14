//
//  MenuBar.swift
//  Claude Usage
//
//  The macOS menu bar glance and popover. The glance shows your tightest limit
//  (the one you will hit first) and, depending on style, the time until it resets
//  or your remaining credits. The popover is the dashboard plus native actions.
//

#if os(macOS)
import SwiftUI
import AppKit
import HeadroomCore

/// Collapsed glance shown in the menu bar, styled per the user's preference.
struct MenuBarLabel: View {
    @Bindable var model: UsageModel
    @Bindable var settings: AppSettings

    private var live: LiveLimits? { model.isSample ? nil : model.snapshot.live }

    /// The window closest to its limit, and when it resets.
    private var binding: (pct: Double, reset: Date?)? {
        guard let live else { return nil }
        var windows: [(Double, Date?)] = []
        if let s = live.fiveHour { windows.append((s.usedPercent, s.resetsAt)) }
        if let w = live.sevenDay { windows.append((w.usedPercent, w.resetsAt)) }
        for m in (live.weeklyByModel ?? []) { windows.append((m.window.usedPercent, m.window.resetsAt)) }
        guard let top = windows.max(by: { $0.0 < $1.0 }) else { return nil }
        return (top.0, top.1)
    }

    var body: some View {
        if let live, let b = binding {
            switch settings.menuBarStyle {
            case .percentage:
                Text("\(pct(b.pct))%").foregroundStyle(color(b.pct))
            case .percentageReset:
                HStack(spacing: 4) {
                    Text("\(pct(b.pct))%").foregroundStyle(color(b.pct))
                    if let r = b.reset { Text(shortReset(r)).foregroundStyle(.secondary) }
                }
            case .timeLeft:
                if let r = b.reset {
                    HStack(spacing: 3) { Image(systemName: "clock"); Text(shortReset(r)) }
                        .foregroundStyle(color(b.pct))
                } else {
                    Text("\(pct(b.pct))%").foregroundStyle(color(b.pct))
                }
            case .credits:
                if let c = live.overageRemaining {
                    Text(money(c))
                } else {
                    Text("\(pct(b.pct))%").foregroundStyle(color(b.pct))
                }
            case .ring:
                HStack(spacing: 4) {
                    ring(b.pct)
                    Text("\(pct(b.pct))%").foregroundStyle(color(b.pct))
                }
            case .sessionWeekly:
                HStack(spacing: 6) {
                    if let s = live.fiveHour { Text("S \(pct(s.usedPercent))%").foregroundStyle(color(s.usedPercent)) }
                    if let w = live.sevenDay { Text("W \(pct(w.usedPercent))%").foregroundStyle(color(w.usedPercent)) }
                }
            }
        } else {
            Image(systemName: "gauge.with.dots.needle.bottom.50percent")
        }
    }

    private func pct(_ p: Double) -> Int { Int(p.rounded()) }
    private func color(_ p: Double) -> Color { Theme.health(p) }

    private func ring(_ p: Double) -> some View {
        ZStack {
            Circle().stroke(.secondary.opacity(0.3), lineWidth: 2.5)
            Circle().trim(from: 0, to: min(1, p / 100))
                .stroke(Theme.health(p), style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
        .frame(width: 12, height: 12)
    }

    private func shortReset(_ d: Date) -> String {
        let s = max(0, d.timeIntervalSinceNow)
        let day = Int(s) / 86_400, h = (Int(s) % 86_400) / 3_600, m = (Int(s) % 3_600) / 60
        if day >= 1 { return "\(day)d" }
        if h >= 1 { return "\(h)h" }
        return "\(max(1, m))m"
    }

    private func money(_ v: Double) -> String {
        v >= 10 ? String(format: "$%.0f", v) : String(format: "$%.2f", v)
    }
}

/// The window style popover: the dashboard plus a native footer with actions.
struct MenuBarPopover: View {
    @Bindable var model: UsageModel
    @Bindable var settings: AppSettings

    var body: some View {
        VStack(spacing: 0) {
            Group {
                if model.claudeConnected {
                    NavigationStack {
                        DashboardView(model: model, settings: settings, translucent: true)
                    }
                } else {
                    OnboardingView(model: model)
                }
            }

            Divider()
            HStack(spacing: 14) {
                SettingsLink { Label("Settings", systemImage: "gearshape") }
                Spacer()
                Button { NSApplication.shared.terminate(nil) } label: {
                    Label("Quit", systemImage: "power")
                }
            }
            .labelStyle(.titleAndIcon)
            .buttonStyle(.borderless)
            .font(.callout)
            .padding(.horizontal, 14).padding(.vertical, 8)
        }
        .frame(width: 380, height: 600)
        .background(.ultraThinMaterial)
    }
}
#endif
