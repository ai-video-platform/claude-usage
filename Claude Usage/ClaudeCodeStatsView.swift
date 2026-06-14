//
//  ClaudeCodeStatsView.swift
//  Claude Usage
//
//  macOS only. With the user's permission we read the local Claude Code logs to
//  show messages, tokens by model, and top projects. Cost is an estimate and off
//  by default. Everything stays on the Mac.
//

#if os(macOS)
import SwiftUI
import HeadroomCore

struct ClaudeCodeStatsView: View {
    @StateObject private var access = ClaudeCodeAccess()
    @State private var stats: UsageSnapshot?
    @State private var loading = false
    @State private var showCost = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                if !access.enabled {
                    enableCard
                } else if let stats {
                    statsContent(stats)
                    revokeRow
                } else if loading {
                    ProgressView().frame(maxWidth: .infinity).padding(.vertical, 40)
                } else {
                    noActivityCard
                    revokeRow
                }
            }
            .padding(16)
            .frame(maxWidth: 560)
            .frame(maxWidth: .infinity)
        }
        .background(Theme.background)
        .navigationTitle("Claude Code")
        .toolbar {
            if access.enabled {
                ToolbarItem(placement: .primaryAction) {
                    Toggle("Show estimated cost", isOn: $showCost)
                }
            }
        }
        .tint(Theme.accent)
        .preferredColorScheme(.dark)
        .task(id: access.enabled) { await reload() }
    }

    private func reload() async {
        guard access.enabled else { stats = nil; return }
        loading = true
        let result = await Task.detached { access.loadStats() }.value
        stats = result
        loading = false
    }

    // MARK: Enable

    private var enableCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: "chevron.left.forwardslash.chevron.right")
                .font(.system(size: 26)).foregroundStyle(Theme.accent)
            Text("See your Claude Code stats").font(.headline).foregroundStyle(Theme.ink)
            Text("Read your local Claude Code logs to show messages, tokens by model, and top projects. This stays on your Mac and nothing is sent anywhere.")
                .font(.caption).foregroundStyle(Theme.inkSecondary).fixedSize(horizontal: false, vertical: true)
            Button { access.requestAccess() } label: {
                Text("Enable").frame(maxWidth: .infinity)
            }
            .glassProminentButton().controlSize(.large).tint(Theme.accent)
            Text("Free, and you can revoke this any time.")
                .font(.caption2).foregroundStyle(Theme.inkTertiary).frame(maxWidth: .infinity, alignment: .center)
        }
        .glassCard(padding: 18)
    }

    private var noActivityCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("No Claude Code activity found")
                .font(.subheadline.weight(.medium)).foregroundStyle(Theme.ink)
            Text("We could not find logs in that folder. Make sure you chose your .claude folder, then try again.")
                .font(.caption).foregroundStyle(Theme.inkSecondary)
            Button("Choose folder again") { access.requestAccess() }
                .glassButton().tint(Theme.accent)
        }
        .glassCard(padding: 16)
    }

    private var revokeRow: some View {
        Button("Turn off and forget this folder", role: .destructive) {
            access.revoke(); stats = nil
        }
        .font(.caption).foregroundStyle(Theme.healthDanger)
        .frame(maxWidth: .infinity, alignment: .center)
    }

    // MARK: Stats

    private func statsContent(_ snap: UsageSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                tile("Messages", "\(snap.allTime.requests)")
                tile("Total tokens", Fmt.tok(snap.allTime.totalTokens))
                if showCost {
                    tile("Estimated cost", Fmt.usd(snap.allTime.costUSD))
                }
            }

            VStack(alignment: .leading, spacing: 10) {
                CardCaption(text: "Tokens by model")
                ForEach(snap.byModel, id: \.family) { m in
                    HStack {
                        Text(m.family).font(.subheadline.weight(.medium)).foregroundStyle(Theme.ink)
                        Spacer()
                        if showCost {
                            Text("\(Fmt.usd(m.costUSD)) est")
                                .font(.caption.monospacedDigit()).foregroundStyle(Theme.inkSecondary)
                        }
                        Text(Fmt.tok(m.totalTokens))
                            .font(.subheadline.monospacedDigit()).foregroundStyle(Theme.ink)
                            .frame(width: 64, alignment: .trailing)
                    }
                }
            }
            .glassCard(padding: 14)

            if !snap.topProjects.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    CardCaption(text: "Top projects")
                    let maxTok = snap.topProjects.map(\.totalTokens).max() ?? 1
                    ForEach(snap.topProjects.prefix(6), id: \.name) { p in
                        VStack(alignment: .leading, spacing: 5) {
                            HStack {
                                Text(p.name).font(.subheadline).foregroundStyle(Theme.ink).lineLimit(1)
                                Spacer()
                                Text(Fmt.tok(p.totalTokens))
                                    .font(.caption.monospacedDigit()).foregroundStyle(Theme.inkSecondary)
                            }
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    Capsule().fill(.white.opacity(0.08))
                                    Capsule().fill(Theme.accent)
                                        .frame(width: geo.size.width * (maxTok > 0 ? Double(p.totalTokens) / Double(maxTok) : 0))
                                }
                            }
                            .frame(height: 5)
                        }
                    }
                }
                .glassCard(padding: 14)
            }

            if showCost {
                Text("Costs are estimated from public token prices, not your actual bill. On a flat fee plan you are not charged per token.")
                    .font(.caption2).foregroundStyle(Theme.inkTertiary).fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func tile(_ caption: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            CardCaption(text: caption)
            Text(value).font(.system(.title3, design: .rounded).weight(.semibold))
                .foregroundStyle(Theme.ink).minimumScaleFactor(0.6).lineLimit(1)
        }
        .glassCard(padding: 12)
    }
}
#endif
