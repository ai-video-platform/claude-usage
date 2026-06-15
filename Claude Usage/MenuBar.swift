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

    /// Session first: the rolling 5 hour limit is the most relevant to a developer.
    /// Falls back to the weekly window when there is no session window.
    private var primary: (pct: Double, reset: Date?)? {
        guard let live else { return nil }
        if let s = live.fiveHour { return (s.usedPercent, s.resetsAt) }
        if let w = live.sevenDay { return (w.usedPercent, w.resetsAt) }
        return nil
    }

    var body: some View {
        if let live, let b = primary {
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
        if day >= 1 { return "\(day)d \(h)h" }
        if h >= 1 { return "\(h)h \(m)m" }
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
        .frame(width: 400, height: 620)
        .background(.ultraThinMaterial)
    }
}
#endif
