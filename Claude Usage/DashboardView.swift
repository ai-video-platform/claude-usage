//
//  DashboardView.swift
//  Claude Usage
//
//  The heart of the app: a calm fuel gauge driven by the signed in claude.ai
//  session. Leads with a plain language verdict, then three distinct windows
//  (Session, Weekly, Weekly Opus) with pace markers and real reset times.
//

import SwiftUI
import HeadroomCore

struct DashboardView: View {
    @Bindable var model: UsageModel
    @Bindable var settings: AppSettings
    /// Hidden when navigation lives in a sidebar (macOS split view).
    var showsNavRows: Bool = true
    /// Lets the menu bar popover glass show through.
    var translucent: Bool = false
    @State private var showSettings = false

    private var snap: UsageSnapshot { model.snapshot }
    private var live: LiveLimits? { snap.live }
    private var hasRealData: Bool { !model.isSample }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                if hasRealData { freshnessLine }
                if model.fetchFailed { failedBanner }
                if hasRealData, let live, let v = Verdict.make(live) {
                    VerdictCapsule(verdict: v)
                }
                limitsCard
                if hasRealData, live?.hasOverage == true { extraUsageCard }
                if showsNavRows {
                    historyRow
                    #if os(macOS)
                    claudeCodeRow
                    #endif
                }
            }
            .padding(16)
            .frame(maxWidth: 580)
            .frame(maxWidth: .infinity)
        }
        .refreshable { await model.refresh() }
        .background { if !translucent { Theme.background } }
        .navigationTitle("Usage")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.large)
        #endif
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { Task { await model.refresh() } } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .disabled(model.isLoading)
                .accessibilityLabel("Refresh")
            }
        }
        .tint(Theme.accent)
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showSettings) { SettingsView(model: model, settings: settings) }
    }

    private var freshnessLine: some View {
        Text(freshnessText).font(.caption).foregroundStyle(Theme.inkTertiary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var freshnessText: String {
        let plan = live?.plan
        if live?.source == "cache" {
            return [plan, "Last known limits, \(Fmt.ago(live?.capturedAt))"].compactMap { $0 }.joined(separator: " · ")
        }
        return [plan, "Updated \(Fmt.ago(snap.generatedAt))"].compactMap { $0 }.joined(separator: " · ")
    }

    // MARK: Limits card

    @ViewBuilder private var limitsCard: some View {
        if let live, hasRealData, (live.fiveHour != nil || live.sevenDay != nil) {
            VStack(alignment: .leading, spacing: 18) {
                MetricBar(label: "Session", percent: live.fiveHour?.usedPercent,
                          resetsAt: live.fiveHour?.resetsAt, showReset: true)
                MetricBar(label: "Weekly", percent: live.sevenDay?.usedPercent,
                          resetsAt: live.sevenDay?.resetsAt, showReset: true)
                ForEach(live.weeklyByModel ?? [], id: \.name) { m in
                    MetricBar(label: m.name, percent: m.window.usedPercent,
                              dotColor: Theme.health(m.window.usedPercent))
                }
                if live.source == "cache" {
                    Label("Showing last known limits. Trying to refresh.",
                          systemImage: "clock.arrow.circlepath")
                        .font(.caption).foregroundStyle(Theme.inkSecondary)
                }
            }
            .glassCard(padding: 18)
        } else {
            loadingCard
        }
    }

    private var loadingCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Loading your limits").font(.headline).foregroundStyle(Theme.ink)
            MetricBar(label: "Session", percent: nil)
            MetricBar(label: "Weekly", percent: nil)
        }
        .glassCard(padding: 18)
    }

    // MARK: Extra usage

    @ViewBuilder private var extraUsageCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                CardCaption(text: "Extra usage")
                Spacer()
                if let remaining = live?.overageRemaining {
                    Text("\(Fmt.usd(remaining)) left")
                        .font(.title3.weight(.semibold).monospacedDigit())
                        .foregroundStyle(Theme.ink)
                }
            }
            if let used = live?.overageUsed, let cap = live?.overageMonthlyLimit, cap > 0 {
                let p = min(100, used / cap * 100)
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(.white.opacity(0.08))
                        Capsule().fill(Theme.health(p)).frame(width: geo.size.width * (p / 100))
                    }
                }
                .frame(height: 6)
                HStack {
                    Text("\(Fmt.usd(used)) of \(Fmt.usd(cap)) this month. Billed separately.")
                    Spacer()
                    Text("\(Int(p.rounded()))% used").foregroundStyle(Theme.health(p))
                }
                .font(.caption).foregroundStyle(Theme.inkSecondary)
            } else {
                Text("Billed separately from your subscription.")
                    .font(.caption).foregroundStyle(Theme.inkSecondary)
            }
        }
        .glassCard(padding: 14)
    }

    // MARK: Navigation rows

    private var historyRow: some View {
        NavigationLink {
            HistoryView(model: model)
        } label: {
            rowLabel("See your last 30 days", systemImage: "chart.line.uptrend.xyaxis")
        }
        .buttonStyle(.plain)
    }

    #if os(macOS)
    private var claudeCodeRow: some View {
        NavigationLink {
            ClaudeCodeStatsView()
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "chevron.left.forwardslash.chevron.right")
                    .font(.subheadline).foregroundStyle(Theme.accent).frame(width: 22)
                Text("Claude Code stats").font(.subheadline).foregroundStyle(Theme.ink)
                Spacer()
                Text("MAC").font(.caption2.weight(.semibold))
                    .foregroundStyle(Theme.inkTertiary)
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(.white.opacity(0.06), in: .capsule)
                Image(systemName: "chevron.right").font(.caption).foregroundStyle(Theme.inkTertiary)
            }
            .glassCard(padding: 14)
        }
        .buttonStyle(.plain)
    }
    #endif

    private func rowLabel(_ title: String, systemImage: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: systemImage)
                .font(.subheadline).foregroundStyle(Theme.accent).frame(width: 22)
            Text(title).font(.subheadline).foregroundStyle(Theme.ink)
            Spacer()
            Image(systemName: "chevron.right").font(.caption).foregroundStyle(Theme.inkTertiary)
        }
        .glassCard(padding: 14)
    }

    // MARK: Could not reach banner

    private var failedBanner: some View {
        Button { showSettings = true } label: {
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(Theme.healthCaution).padding(.top, 1)
                (
                    Text("Could not reach Claude. ").foregroundStyle(Theme.ink)
                    + Text("Check your connection, or sign in again in Settings.").foregroundStyle(Theme.inkSecondary)
                )
                .font(.caption).fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            }
            .padding(12)
            .background(Theme.healthCaution.opacity(0.12), in: .rect(cornerRadius: Theme.cornerTile))
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    DashboardView(model: UsageModel(), settings: AppSettings())
}
