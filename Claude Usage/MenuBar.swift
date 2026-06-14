//
//  MenuBar.swift
//  Claude Usage
//
//  The macOS menu bar glance and the popover. The glance honors the user's
//  chosen style; the popover is the condensed dashboard.
//

#if os(macOS)
import SwiftUI
import HeadroomCore

/// Collapsed glance shown in the menu bar, styled per the user's preference.
struct MenuBarLabel: View {
    @Bindable var model: UsageModel
    @Bindable var settings: AppSettings

    private var weekly: Double? { value(model.snapshot.live?.sevenDay?.usedPercent) }
    private var session: Double? { value(model.snapshot.live?.fiveHour?.usedPercent) }

    private func value(_ pct: Double?) -> Double? {
        guard let pct, !model.isSample else { return nil }
        return pct
    }

    var body: some View {
        if weekly == nil && session == nil {
            Image(systemName: "gauge.with.dots.needle.bottom.50percent")
        } else {
            switch settings.menuBarStyle {
            case .percentage: percentageStyle
            case .miniBar: miniBarStyle
            case .miniRing: miniRingStyle
            case .iconFill: iconFillStyle
            case .sessionWeekly: sessionWeeklyStyle
            }
        }
    }

    private func shown(_ used: Double) -> Int {
        Int(used.rounded())
    }

    @ViewBuilder private var percentageStyle: some View {
        if let w = weekly {
            if settings.showWeeklyInMenuBar, let s = session {
                Text("S \(shown(s))%  W \(shown(w))%").foregroundStyle(Theme.health(w))
            } else {
                Text("\(shown(w))%").foregroundStyle(Theme.health(w))
            }
        }
    }

    @ViewBuilder private var miniBarStyle: some View {
        if let w = weekly {
            ZStack(alignment: .leading) {
                Capsule().fill(.secondary.opacity(0.3)).frame(width: 26, height: 6)
                Capsule().fill(Theme.health(w)).frame(width: 26 * min(1, w / 100), height: 6)
            }
        }
    }

    @ViewBuilder private var miniRingStyle: some View {
        if let w = weekly {
            ZStack {
                Circle().stroke(.secondary.opacity(0.3), lineWidth: 3)
                Circle().trim(from: 0, to: min(1, w / 100))
                    .stroke(Theme.health(w), style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .rotationEffect(.degrees(-90))
            }
            .frame(width: 15, height: 15)
        }
    }

    @ViewBuilder private var iconFillStyle: some View {
        if let w = weekly {
            Image(systemName: symbol(w)).foregroundStyle(settings.fillIconByUsage ? Theme.health(w) : .primary)
        }
    }

    @ViewBuilder private var sessionWeeklyStyle: some View {
        if let w = weekly {
            HStack(spacing: 6) {
                if let s = session { Text("S \(shown(s))%").foregroundStyle(Theme.health(s)) }
                Text("W \(shown(w))%").foregroundStyle(Theme.health(w))
            }
        }
    }

    private func symbol(_ pct: Double) -> String {
        switch pct {
        case ..<34: return "gauge.with.dots.needle.bottom.0percent"
        case ..<67: return "gauge.with.dots.needle.bottom.50percent"
        default: return "gauge.with.dots.needle.bottom.100percent"
        }
    }
}

/// The window style popover content: the dashboard, sized for the menu bar.
struct MenuBarPopover: View {
    @Bindable var model: UsageModel
    @Bindable var settings: AppSettings

    var body: some View {
        Group {
            if model.claudeConnected {
                NavigationStack {
                    DashboardView(model: model, settings: settings, translucent: true)
                }
            } else {
                OnboardingView(model: model)
            }
        }
        .frame(width: 380, height: 600)
        .background(.ultraThinMaterial)
    }
}
#endif
