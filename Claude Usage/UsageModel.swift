//
//  UsageModel.swift
//  Claude Usage
//
//  Client-side, sandboxed data layer. The only data source is the user's own
//  claude.ai session (signed in on Anthropic's page; the session key lives only in
//  this device's Keychain). Nothing is sent to any server of ours.
//

import Foundation
import Observation
import WidgetKit
import HeadroomCore

@MainActor
@Observable
final class UsageModel {
    var snapshot: UsageSnapshot = .sample
    var claudeConnected: Bool = KeychainStore.get(KeychainStore.claudeSessionAccount) != nil
    var isSample: Bool = true
    var isLoading: Bool = false
    /// Signed in, but the last fetch failed (expired session or offline).
    var fetchFailed: Bool = false
    var lastRefreshed: Date?
    /// Sample-data preview (also used by App Review, who cannot sign in to claude.ai).
    private(set) var demoMode = false
    /// In memory demo history (QA only). Never read from or written to disk.
    var demoHistory: UsageHistory?

    private var autoRefreshTask: Task<Void, Never>?

    /// Background refresh loop (>=180s keeps us under claude.ai's polite-poll guidance).
    func startAutoRefresh(interval: TimeInterval = 300) {
        guard autoRefreshTask == nil else { return }
        autoRefreshTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.refresh()
                try? await Task.sleep(for: .seconds(interval))
            }
        }
    }

    /// Visual QA / screenshot mode. Seeds realistic data in memory only, never to
    /// disk, so it can never leak into the real app or the widgets.
    func loadDemo() {
        demoMode = true
        demoHistory = DemoData.history
        snapshot = DemoData.snapshot
        isSample = false
        fetchFailed = false
        claudeConnected = true
    }

    /// Called after the user completes the in-app Claude sign-in.
    func markClaudeConnected() {
        demoMode = false
        demoHistory = nil
        claudeConnected = true
        fetchFailed = false
        NotificationManager.requestAuthorization()   // ask in context, not over onboarding
        Task { await refresh() }
    }

    func disconnectClaude() {
        KeychainStore.delete(KeychainStore.claudeSessionAccount)
        demoMode = false
        demoHistory = nil
        claudeConnected = false
        fetchFailed = false
        isSample = true
        snapshot = .sample
    }

    func refresh() async {
        guard claudeConnected, !demoMode else { return }
        isLoading = true
        defer { isLoading = false }
        if let loaded = await Self.fetchSnapshot() {
            snapshot = loaded
            isSample = false
            fetchFailed = false
            SnapshotStore.save(loaded)                 // on-device App Group -> widgets
            // Only record fresh readings into history, not cache fallbacks.
            if let live = loaded.live, live.source != "cache" {
                Task.detached {
                    HistoryStore.record(session: live.fiveHour?.usedPercent,
                                        weekly: live.sevenDay?.usedPercent,
                                        opus: live.sevenDayOpus?.usedPercent,
                                        sonnet: live.sevenDaySonnet?.usedPercent)
                }
            }
            WidgetCenter.shared.reloadAllTimelines()
            NotificationManager.evaluateIfEnabled(loaded)
        } else {
            fetchFailed = true                         // no fresh data and no recent cache
        }
        lastRefreshed = Date()
    }

    /// Fetches usage from the signed-in claude.ai session. Entirely client-side.
    /// Retries once, then falls back to the recent cache so a transient network or
    /// Cloudflare blip does not look like an expired session.
    nonisolated static func fetchSnapshot() async -> UsageSnapshot? {
        let key = await Task.detached(priority: .userInitiated) {
            KeychainStore.get(KeychainStore.claudeSessionAccount)
        }.value
        guard let key else { return nil }
        let client = LiveLimitsClient()
        var live = await client.viaClaudeWeb(sessionKey: key)
        if live == nil {
            try? await Task.sleep(for: .seconds(2))
            live = await client.viaClaudeWeb(sessionKey: key)
        }
        guard let fresh = LiveLimitsCache.freshest(live) else { return nil }
        return SnapshotBuilder().build(records: [], live: fresh)
    }
}
