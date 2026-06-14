//
//  MacRootView.swift
//  Claude Usage
//
//  Native macOS structure: a Liquid Glass sidebar (NavigationSplitView) with the
//  selected section in the detail. This is what makes it feel like a first party
//  Mac app rather than a ported iOS view.
//

#if os(macOS)
import SwiftUI

struct MacRootView: View {
    @Bindable var model: UsageModel
    @Bindable var settings: AppSettings
    @State private var section: MacSection = .today

    enum MacSection: String, CaseIterable, Identifiable {
        case today, history, claudeCode, settings
        var id: String { rawValue }
        var title: String {
            switch self {
            case .today: return "Today"
            case .history: return "History"
            case .claudeCode: return "Claude Code"
            case .settings: return "Settings"
            }
        }
        var symbol: String {
            switch self {
            case .today: return "gauge.with.dots.needle.bottom.50percent"
            case .history: return "chart.bar"
            case .claudeCode: return "chevron.left.forwardslash.chevron.right"
            case .settings: return "gearshape"
            }
        }
    }

    var body: some View {
        NavigationSplitView {
            List(MacSection.allCases, selection: $section) { item in
                Label(item.title, systemImage: item.symbol).tag(item)
            }
            .navigationTitle("Claude Usage")
            .navigationSplitViewColumnWidth(min: 190, ideal: 210, max: 260)
        } detail: {
            NavigationStack {
                detail
            }
            .frame(minWidth: 480, minHeight: 560)
        }
        .frame(minWidth: 720, minHeight: 620)
        .tint(Theme.accent)
        .preferredColorScheme(.dark)
    }

    @ViewBuilder private var detail: some View {
        switch section {
        case .today: DashboardView(model: model, settings: settings, showsNavRows: false)
        case .history: HistoryView(model: model)
        case .claudeCode: ClaudeCodeStatsView()
        case .settings: SettingsView(model: model, settings: settings)
        }
    }
}
#endif
