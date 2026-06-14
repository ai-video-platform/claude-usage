import Foundation
import HeadroomCore

// Headroom CLI. Subcommands:
//   report      (default)  print a usage report from ~/.claude and write snapshot.json
//   statusline             read Claude Code's stdin payload, capture live limits, print a gauge
//   snapshot               print the merged snapshot JSON (engine + live limits)

func usd(_ v: Double) -> String { String(format: "$%.2f", v) }
func tok(_ n: Int) -> String {
    if n >= 1_000_000 { return String(format: "%.2fM", Double(n) / 1_000_000) }
    if n >= 1_000 { return String(format: "%.1fk", Double(n) / 1_000) }
    return "\(n)"
}
func bar(_ fraction: Double, width: Int = 20) -> String {
    let filled = max(0, min(width, Int((fraction * Double(width)).rounded())))
    return String(repeating: "█", count: filled) + String(repeating: "░", count: width - filled)
}
func pad(_ s: String, _ n: Int) -> String {
    s.count >= n ? s : s + String(repeating: " ", count: n - s.count)
}

func loadLiveLimits() -> LiveLimits? {
    guard let data = try? Data(contentsOf: SupportDir.liveJSON) else { return nil }
    return try? HeadroomJSON.decoder.decode(LiveLimits.self, from: data)
}

// MARK: - statusline: capture live limits, echo a compact gauge

func runStatusline() {
    let stdin = FileHandle.standardInput.readDataToEndOfFile()
    guard let live = Statusline.parse(stdin) else {
        print("Headroom: no limit data (API-key session?)")
        return
    }
    SupportDir.ensure()
    if let data = try? HeadroomJSON.encoder.encode(live) {
        try? data.write(to: SupportDir.liveJSON)
    }
    print(Statusline.renderLine(live))
}

// MARK: - snapshot: emit the render contract as JSON

func runSnapshot() {
    let records = UsageStore().loadRecords()
    let snap = SnapshotBuilder().build(records: records, live: loadLiveLimits())
    SupportDir.ensure()
    if let data = try? HeadroomJSON.encoder.encode(snap) {
        try? data.write(to: SupportDir.snapshotJSON)
        FileHandle.standardOutput.write(data)
        print("")
    }
}

// MARK: - report: human-readable summary

func runReport() {
    let store = UsageStore()
    let t0 = Date()
    let records = store.loadRecords()
    let report = store.aggregate(records)
    let scanTime = Date().timeIntervalSince(t0)
    let live = loadLiveLimits()

    let dateFmt = DateFormatter()
    dateFmt.dateFormat = "yyyy-MM-dd HH:mm"

    print("")
    print("  HEADROOM — Claude usage engine")
    print("  ────────────────────────────────────────────────────")
    print("  Parsed \(records.count) billed requests across \(report.sessions.count) sessions in \(String(format: "%.2f", scanTime))s")
    if let first = report.firstSeen, let last = report.lastSeen {
        print("  Activity range: \(dateFmt.string(from: first))  →  \(dateFmt.string(from: last))")
    }
    print("")

    if let live {
        print("  LIVE LIMITS (captured \(dateFmt.string(from: live.capturedAt)))")
        if let wk = live.sevenDay {
            print("    Weekly  \(bar(wk.usedPercent / 100, width: 20)) \(Int(wk.usedPercent))%")
        }
        if let fh = live.fiveHour {
            print("    5 hour  \(bar(fh.usedPercent / 100, width: 20)) \(Int(fh.usedPercent))%")
        }
        print("")
    } else {
        print("  LIVE LIMITS: none captured yet (run the statusline hook inside Claude Code)")
        print("")
    }

    let o = report.overall
    print("  ALL-TIME")
    print("    Estimated cost   \(usd(o.cost))")
    print("    Tokens           \(tok(o.totalTokens))  (in \(tok(o.input)) · out \(tok(o.output)) · cache-w \(tok(o.cacheWrite)) · cache-r \(tok(o.cacheRead)))")
    print("")

    print("  BY MODEL")
    let maxModelCost = report.byModel.values.map(\.cost).max() ?? 1
    for fam in ModelFamily.allCases {
        guard let t = report.byModel[fam.rawValue], t.requests > 0 else { continue }
        let frac = maxModelCost > 0 ? t.cost / maxModelCost : 0
        print("    \(pad(fam.display, 8)) \(bar(frac, width: 16)) \(pad(usd(t.cost), 10)) \(tok(t.totalTokens)) tok")
    }
    print("")

    if let last = report.lastSeen {
        let week = store.window(records, since: last.addingTimeInterval(-7 * 24 * 3600), until: last)
        let day  = store.window(records, since: last.addingTimeInterval(-24 * 3600), until: last)
        let fiveH = store.window(records, since: last.addingTimeInterval(-5 * 3600), until: last)
        print("  ROLLING WINDOWS (anchored to last activity)")
        print("    Last 5 hours   \(usd(fiveH.cost))   \(tok(fiveH.totalTokens)) tok   \(fiveH.requests) req")
        print("    Last 24 hours  \(usd(day.cost))   \(tok(day.totalTokens)) tok   \(day.requests) req")
        print("    Last 7 days    \(usd(week.cost))   \(tok(week.totalTokens)) tok   \(week.requests) req")
        print("")
    }

    print("  TOP PROJECTS BY COST")
    for (name, t) in report.byProject.sorted(by: { $0.value.cost > $1.value.cost }).prefix(10) {
        print("    \(pad(name, 22)) \(pad(usd(t.cost), 10)) \(tok(t.totalTokens)) tok")
    }
    print("")

    // Persist a snapshot so the (future) app + widgets have something to render.
    let snap = SnapshotBuilder().build(records: records, live: live)
    SupportDir.ensure()
    if let data = try? HeadroomJSON.encoder.encode(snap) {
        try? data.write(to: SupportDir.snapshotJSON)
        print("  Wrote snapshot → \(SupportDir.snapshotJSON.path)")
    }
    print("")
}

// MARK: - live: prove the live-limits paths on this machine

let dateFmtLive: DateFormatter = {
    let f = DateFormatter()
    f.dateFormat = "EEE MMM d, h:mm a"
    return f
}()

func runLive() async {
    let args = Array(CommandLine.arguments.dropFirst())
    let client = LiveLimitsClient()
    var live: LiveLimits?

    if let i = args.firstIndex(of: "--cookie"), i + 1 < args.count {
        print("  Fetching via claude.ai web session (full data + credits)...")
        live = await client.viaClaudeWeb(sessionKey: args[i + 1])
    } else {
        guard let token = CredentialStore().oauthAccessToken() else {
            print("  No Claude Code OAuth token found (checked ~/.claude/.credentials.json and Keychain).")
            print("  Tip: pass --cookie <sessionKey> to test the claude.ai web path instead.")
            return
        }
        print("  Found OAuth token; calling the Anthropic API for rate-limit headers...")
        live = await client.viaOAuthHeaders(token: token)
    }

    guard let live else {
        print("  No live limits returned (endpoint may have changed, or auth failed).")
        return
    }
    LiveLimitsCache.save(live)
    func resetStr(_ d: Date?) -> String { d.map { dateFmtLive.string(from: $0) } ?? "?" }

    print("")
    print("  LIVE LIMITS  (source: \(live.source ?? "?"))")
    if let w = live.sevenDay { print("    Weekly  \(bar(w.usedPercent / 100, width: 20)) \(Int(w.usedPercent))%   resets \(resetStr(w.resetsAt))") }
    if let f = live.fiveHour { print("    5 hour  \(bar(f.usedPercent / 100, width: 20)) \(Int(f.usedPercent))%   resets \(resetStr(f.resetsAt))") }
    if let o = live.sevenDayOpus { print("    Opus    \(Int(o.usedPercent))%") }
    if let s = live.sevenDaySonnet { print("    Sonnet  \(Int(s.usedPercent))%") }
    if live.hasOverage {
        let rem = live.overageRemaining.map { String(format: "$%.2f", $0) } ?? "?"
        let used = live.overageUsed.map { String(format: "$%.2f", $0) } ?? "?"
        let cap = live.overageMonthlyLimit.map { String(format: "$%.2f", $0) } ?? "?"
        print("    Extra usage: remaining \(rem)   used \(used) / \(cap)")
    }
    print("")
}

// MARK: - dispatch

switch CommandLine.arguments.dropFirst().first {
case "statusline": runStatusline()
case "snapshot":   runSnapshot()
case "live":       await runLive()
default:           runReport()
}
