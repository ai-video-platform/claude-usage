//
//  ContentView.swift
//  Claude Usage
//
//  Root: onboarding until signed in, then the tabbed app on iOS / iPadOS and the
//  native split view on macOS. Containers own the NavigationStack so every screen
//  uses native navigation titles and toolbars.
//

import SwiftUI

struct ContentView: View {
    @Bindable var model: UsageModel
    @Bindable var settings: AppSettings

    private var qaScreen: String? { ProcessInfo.processInfo.environment["CU_SCREEN"] }
    private var isDemo: Bool { ProcessInfo.processInfo.environment["CU_DEMO"] == "1" }

    var body: some View {
        Group {
            if model.claudeConnected {
                if let qaScreen { qaRoute(qaScreen) } else { mainApp }
            } else {
                OnboardingView(model: model)
            }
        }
        .task { if isDemo { model.loadDemo() } }
    }

    @ViewBuilder private var mainApp: some View {
        #if os(iOS)
        TabView {
            NavigationStack { DashboardView(model: model, settings: settings) }
                .tabItem { Label("Today", systemImage: "gauge.with.dots.needle.bottom.50percent") }
            NavigationStack { HistoryView(model: model) }
                .tabItem { Label("History", systemImage: "chart.bar") }
            NavigationStack { SettingsView(model: model, settings: settings) }
                .tabItem { Label("Settings", systemImage: "slider.horizontal.3") }
        }
        .tint(Theme.accent)
        .preferredColorScheme(.dark)
        #else
        MacRootView(model: model, settings: settings)
        #endif
    }

    // QA only: launch straight into a screen for screenshots.
    @ViewBuilder private func qaRoute(_ screen: String) -> some View {
        switch screen {
        case "history": NavigationStack { HistoryView(model: model) }
        case "settings": NavigationStack { SettingsView(model: model, settings: settings) }
        case "gallery": GalleryView(page: 0)
        case "gallery2": GalleryView(page: 1)
        case "rules": NavigationStack { RulesListView(settings: settings) }
        case "editor": RuleEditorView(rule: NotificationRule(), allowFreeText: true) { _ in }
        #if canImport(WebKit)
        case "connect": ConnectClaudeView { }
        #endif
        #if os(macOS)
        case "claudecode": NavigationStack { ClaudeCodeStatsView() }
        #endif
        default: NavigationStack { DashboardView(model: model, settings: settings) }
        }
    }
}

#Preview {
    ContentView(model: UsageModel(), settings: AppSettings())
}
