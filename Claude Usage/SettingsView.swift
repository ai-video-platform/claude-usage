//
//  SettingsView.swift
//  Claude Usage
//
//  Grouped settings: connection, display and ambient, alerts, privacy, about.
//  Shown as a tab on iOS, and as the Settings scene (and a sheet) on macOS.
//

import SwiftUI
import HeadroomCore

struct SettingsView: View {
    @Bindable var model: UsageModel
    @Bindable var settings: AppSettings
    @State private var showConnect = false

    var body: some View {
        Form {
            connectionSection
            displaySection
            alertsSection
            privacySection
            aboutSection
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .background(Theme.background)
        .navigationTitle("Settings")
        .tint(Theme.accent)
        .preferredColorScheme(.dark)
        #if os(macOS)
        .frame(minWidth: 460, minHeight: 520)
        #endif
        #if canImport(WebKit)
        .sheet(isPresented: $showConnect) {
            ConnectClaudeView { model.markClaudeConnected() }
        }
        #endif
    }

    // MARK: Connection

    @ViewBuilder private var connectionSection: some View {
        Section {
            if model.demoMode {
                Label("Showing sample data", systemImage: "eye")
                    .foregroundStyle(.secondary)
                Button("Sign in to Claude") { showConnect = true }
            } else if model.claudeConnected {
                HStack {
                    Label {
                        VStack(alignment: .leading, spacing: 1) {
                            Text("Connected to claude.ai")
                            if let plan = model.snapshot.live?.plan, !model.isSample {
                                Text(plan).font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    } icon: {
                        Circle().fill(Theme.healthSafe).frame(width: 9, height: 9)
                    }
                    Spacer()
                }
                Button("Sign out", role: .destructive) { model.disconnectClaude() }
            } else {
                Text("Sign in with the email you use for claude.ai. Pro and Max plans. Team, Enterprise, and Google sign in are not supported.")
                    .font(.caption).foregroundStyle(.secondary)
                Button("Sign in to Claude") { showConnect = true }
            }
        } header: {
            Text("Connection")
        }
    }

    // MARK: Display and ambient

    @ViewBuilder private var displaySection: some View {
        Section {
            Picker("Default widget", selection: $settings.defaultWidgetMetric) {
                Text("Session").tag(WidgetMetric.session)
                Text("Weekly").tag(WidgetMetric.weekly)
            }
            #if os(macOS)
            Picker("Menu bar shows", selection: $settings.menuBarStyle) {
                ForEach(MenuBarStyle.allCases, id: \.self) { Text($0.title).tag($0) }
            }
            Picker("Dashboard text size", selection: $settings.dashboardTextSize) {
                Text("Small").tag(DashboardTextSize.small)
                Text("Medium").tag(DashboardTextSize.medium)
                Text("Large").tag(DashboardTextSize.large)
            }            #endif
        } header: {
            Text("Display")
        }
    }

    // MARK: Alerts

    @ViewBuilder private var alertsSection: some View {
        Section {
            Toggle("Enable notifications", isOn: $settings.notificationsEnabled)
            NavigationLink {
                RulesListView(settings: settings)
            } label: {
                HStack {
                    Text("Notification rules")
                    Spacer()
                    Text("\(settings.rules.filter(\.enabled).count) active").foregroundStyle(.secondary)
                }
            }
            Picker("Time format", selection: $settings.timeFormat) {
                Text("System").tag(TimeFormatPref.system)
                Text("24 hour").tag(TimeFormatPref.h24)
                Text("12 hour").tag(TimeFormatPref.h12)
            }        } header: {
            Text("Alerts")
        }
    }

    // MARK: Privacy

    private var privacySection: some View {
        Section {
            privacyLine("Everything stays on this device. There are no servers.")
            privacyLine("You sign in on Claude's own page. We never see your password.")
            privacyLine("Your session is stored only in this device's Keychain.")
            Link(destination: AppInfo.privacyURL) {
                Label("Privacy policy", systemImage: "hand.raised")
            }
        } header: {
            Text("Privacy")
        }
    }

    private func privacyLine(_ text: String) -> some View {
        Label(text, systemImage: "checkmark.circle.fill")
            .font(.caption)
            .labelStyle(.titleAndIcon)
            .foregroundStyle(.secondary)
    }

    // MARK: About

    private var aboutSection: some View {
        Section {
            HStack {
                Text("Version")
                Spacer()
                Text(appVersion).foregroundStyle(.secondary)
            }
            Link(destination: AppInfo.repoURL) {
                Label("Source code on GitHub", systemImage: "chevron.left.forwardslash.chevron.right")
            }
            Text("Free and open source, with no in app purchases.")
                .font(.caption).foregroundStyle(.secondary)
            Text("\(AppInfo.disclaimer) It reads your usage from claude.ai and may need an update if Claude changes its site.")
                .font(.caption).foregroundStyle(.secondary)
        } header: {
            Text("About")
        }
    }

    private var appVersion: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(v) (\(b))"
    }
}

#Preview {
    SettingsView(model: UsageModel(), settings: AppSettings())
}
