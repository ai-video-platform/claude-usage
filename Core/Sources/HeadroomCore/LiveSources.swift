import Foundation
import Security

// MARK: - Credentials

/// Reads the Claude Code OAuth access token, file first then macOS Keychain.
/// Used for the low-privilege "OAuth headers" live-limits path.
public struct CredentialStore: Sendable {
    public init() {}

    public func oauthAccessToken() -> String? {
        if let t = tokenFromFile() { return t }
        #if os(macOS)
        if let t = tokenFromKeychain() { return t }
        #endif
        return nil
    }

    func tokenFromFile() -> String? {
        let candidates = [
            ClaudePaths.home.appendingPathComponent(".credentials.json"),
            ClaudePaths.home.appendingPathComponent("credentials.json"),
        ]
        for url in candidates {
            if let data = try? Data(contentsOf: url),
               let token = Self.extractAccessToken(from: data) {
                return token
            }
        }
        return nil
    }

    /// Claude Code stores credentials as JSON: {"claudeAiOauth": {"accessToken": "..."}}
    /// or a flat {"accessToken": "..."}.
    static func extractAccessToken(from data: Data) -> String? {
        guard let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        if let oauth = obj["claudeAiOauth"] as? [String: Any], let t = oauth["accessToken"] as? String { return t }
        if let t = obj["accessToken"] as? String { return t }
        return nil
    }

    #if os(macOS)
    func tokenFromKeychain() -> String? {
        // Base service name, then the hashed variant Claude Code 2.1.52+ uses.
        var services = ["Claude Code-credentials"]
        if let hashed = hashedServiceName() { services.append(hashed) }
        for service in services {
            guard let raw = Self.runSecurity(["find-generic-password", "-s", service, "-w"]) else { continue }
            let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            if let token = Self.extractAccessToken(from: Data(trimmed.utf8)) { return token }
        }
        return nil
    }

    /// Discovers a "Claude Code-credentials-<hash>" service (Claude Code 2.1.52+).
    /// Prefer an in-process attribute enumeration (no secrets, no prompt); only fall
    /// back to the broader `security dump-keychain` if that finds nothing.
    func hashedServiceName() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecMatchLimit as String: kSecMatchLimitAll,
            kSecReturnAttributes as String: true,
        ]
        var result: CFTypeRef?
        if SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
           let items = result as? [[String: Any]] {
            for item in items {
                if let svc = item[kSecAttrService as String] as? String,
                   svc.hasPrefix("Claude Code-credentials-") { return svc }
            }
        }
        if let dump = Self.runSecurity(["dump-keychain"], timeout: 6) {
            for line in dump.split(separator: "\n") where line.contains("Claude Code-credentials-") {
                if let range = line.range(of: "Claude Code-credentials-[A-Za-z0-9]+", options: .regularExpression) {
                    return String(line[range])
                }
            }
        }
        return nil
    }

    /// Runs /usr/bin/security with a hard timeout so a keychain prompt can't hang us forever.
    static func runSecurity(_ args: [String], timeout: TimeInterval = 4) -> String? {
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/security")
        proc.arguments = args
        let pipe = Pipe()
        proc.standardOutput = pipe
        proc.standardError = FileHandle.nullDevice
        do { try proc.run() } catch { return nil }
        let deadline = Date().addingTimeInterval(timeout)
        while proc.isRunning && Date() < deadline { usleep(50_000) }
        if proc.isRunning { proc.terminate(); return nil }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard proc.terminationStatus == 0 else { return nil }
        return String(data: data, encoding: .utf8)
    }
    #endif
}

// MARK: - Live limits client

/// Fetches live limits from the two chosen paths. Both are private/undocumented;
/// callers wrap results in LiveLimitsCache for graceful degradation.
public struct LiveLimitsClient: Sendable {
    let session: URLSession
    public init(session: URLSession = .shared) { self.session = session }

    private static let claudeBase = "https://claude.ai/api"

    // MARK: OAuth-headers path (low privilege, 5h + weekly % only)

    public func viaOAuthHeaders(token: String, now: Date = Date()) async -> LiveLimits? {
        guard let url = URL(string: "https://api.anthropic.com/v1/messages") else { return nil }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue("oauth-2025-04-20", forHTTPHeaderField: "anthropic-beta")
        req.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        req.setValue("claude-code/2.1.5 (external, cli)", forHTTPHeaderField: "User-Agent")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Any] = [
            "model": "claude-haiku-4-5-20251001",
            "max_tokens": 1,
            "messages": [["role": "user", "content": "hi"]],
        ]
        req.httpBody = try? JSONSerialization.data(withJSONObject: body)

        guard let (_, resp) = try? await session.data(for: req),
              let http = resp as? HTTPURLResponse else { return nil }
        var headers: [String: String] = [:]
        for (k, v) in http.allHeaderFields {
            if let key = k as? String, let val = v as? String { headers[key.lowercased()] = val }
        }
        return Self.parseRateLimitHeaders(headers, now: now)
    }

    // MARK: claude.ai web path (full data + extra credits)

    public func viaClaudeWeb(sessionKey: String, now: Date = Date()) async -> LiveLimits? {
        guard let org = await fetchOrg(sessionKey: sessionKey) else { return nil }
        let id = org.id
        async let usageData = getData("/organizations/\(id)/usage", sessionKey: sessionKey)
        async let grantData = getData("/organizations/\(id)/overage_credit_grant", sessionKey: sessionKey)
        async let limitData = getData("/organizations/\(id)/overage_spend_limit", sessionKey: sessionKey)
        let (usage, grant, limit) = await (usageData, grantData, limitData)

        guard let usage, var live = Self.parseClaudeUsage(usage, now: now) else { return nil }
        if let grant { Self.applyOverageGrant(grant, to: &live) }
        if let limit { Self.applyOverageLimit(limit, to: &live) }
        live.plan = org.plan
        live.source = "claude-web"
        return live
    }

    /// Resolves the org to read, preferring the Max org, then Pro, then the first.
    /// Returns the org id and a display plan name ("Max"/"Pro") from its capabilities.
    private func fetchOrg(sessionKey: String) async -> (id: String, plan: String?)? {
        guard let data = await getData("/organizations", sessionKey: sessionKey),
              let arr = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]], !arr.isEmpty
        else { return nil }
        func caps(_ o: [String: Any]) -> [String] { (o["capabilities"] as? [String]) ?? [] }
        let chosen = arr.first(where: { caps($0).contains("claude_max") })
            ?? arr.first(where: { caps($0).contains("claude_pro") })
            ?? arr[0]
        guard let id = chosen["uuid"] as? String ?? chosen["id"] as? String else { return nil }
        let c = caps(chosen)
        let plan = c.contains("claude_max") ? "Max" : (c.contains("claude_pro") ? "Pro" : nil)
        return (id, plan)
    }

    private func getData(_ path: String, sessionKey: String) async -> Data? {
        guard let url = URL(string: Self.claudeBase + path) else { return nil }
        var req = URLRequest(url: url)
        req.setValue("sessionKey=\(sessionKey)", forHTTPHeaderField: "Cookie")
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        req.setValue("https://claude.ai", forHTTPHeaderField: "Referer")
        req.setValue("https://claude.ai", forHTTPHeaderField: "Origin")
        req.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15",
                     forHTTPHeaderField: "User-Agent")
        guard let (data, resp) = try? await session.data(for: req),
              let http = resp as? HTTPURLResponse, (200...299).contains(http.statusCode) else { return nil }
        return data
    }

    // MARK: - Parsers (pure, unit-tested)

    public static func parseRateLimitHeaders(_ h: [String: String], now: Date = Date()) -> LiveLimits? {
        func window(_ utilKey: String, _ resetKey: String) -> LimitWindow? {
            guard let raw = h[utilKey], let util = Double(raw) else { return nil }
            return LimitWindow(usedPercent: normalizePercent(util), resetsAt: parseReset(h[resetKey]))
        }
        let five = window("anthropic-ratelimit-unified-5h-utilization", "anthropic-ratelimit-unified-5h-reset")
        let seven = window("anthropic-ratelimit-unified-7d-utilization", "anthropic-ratelimit-unified-7d-reset")
        guard five != nil || seven != nil else { return nil }
        return LiveLimits(capturedAt: now, fiveHour: five, sevenDay: seven, source: "oauth-headers")
    }

    public static func parseClaudeUsage(_ data: Data, now: Date = Date()) -> LiveLimits? {
        guard let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        func windowFrom(_ w: [String: Any]) -> LimitWindow? {
            // claude.ai /usage reports utilization (and used_percentage) on a 0...100 scale.
            if let util = w["utilization"] as? Double {
                return LimitWindow(usedPercent: util, resetsAt: parseReset(w["resets_at"]))
            }
            if let pct = w["used_percentage"] as? Double {
                return LimitWindow(usedPercent: pct, resetsAt: parseReset(w["resets_at"]))
            }
            return nil
        }
        func window(_ key: String) -> LimitWindow? {
            guard let w = obj[key] as? [String: Any] else { return nil }
            return windowFrom(w)
        }
        let five = window("five_hour")
        let seven = window("seven_day")
        guard five != nil || seven != nil else { return nil }

        // Data driven per model weekly sub limits: any "seven_day_<model>" key the API
        // returns, named from the key, so new models surface automatically.
        var models: [ModelWindow] = []
        for (k, v) in obj where k.hasPrefix("seven_day_") {
            guard let w = v as? [String: Any], let lw = windowFrom(w) else { continue }
            let token = String(k.dropFirst("seven_day_".count))
            models.append(ModelWindow(name: ModelFamily.display(forToken: token), window: lw))
        }
        models.sort { $0.window.usedPercent > $1.window.usedPercent }

        var live = LiveLimits(capturedAt: now, fiveHour: five, sevenDay: seven,
                              sevenDayOpus: window("seven_day_opus"),
                              sevenDaySonnet: window("seven_day_sonnet"),
                              weeklyByModel: models.isEmpty ? nil : models,
                              source: "claude-web")
        // /usage embeds an extra_usage block; the separate overage endpoints fill in the rest.
        if let extra = obj["extra_usage"] as? [String: Any], (extra["is_enabled"] as? Bool) == true {
            live.overageMonthlyLimit = dollars(extra["monthly_limit"])
            live.overageUsed = dollars(extra["used_credits"])
        }
        return live
    }

    static func applyOverageGrant(_ data: Data, to live: inout LiveLimits) {
        guard let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }
        live.overageRemaining = dollars(obj["remaining_balance"])
        live.overageCurrency = (obj["currency"] as? String) ?? live.overageCurrency
    }

    static func applyOverageLimit(_ data: Data, to live: inout LiveLimits) {
        guard let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }
        if (obj["is_enabled"] as? Bool) == true {
            live.overageMonthlyLimit = dollars(obj["monthly_credit_limit"])
            live.overageUsed = dollars(obj["used_credits"])
            live.overageCurrency = (obj["currency"] as? String) ?? live.overageCurrency
        }
    }

    // MARK: helpers

    /// Overage credits come from the API in integer cents. Convert to dollars.
    static func dollars(_ any: Any?) -> Double? {
        if let n = any as? Double { return n / 100 }
        if let n = any as? Int { return Double(n) / 100 }
        return nil
    }

    /// claude.ai returns 0.0–1.0; headers may already be a percentage. Normalize to 0–100.
    static func normalizePercent(_ v: Double) -> Double { v <= 1.0 ? v * 100 : v }

    /// resets_at may be a unix epoch number or an ISO 8601 string.
    static func parseReset(_ any: Any?) -> Date? {
        if let s = any as? String {
            if let d = UsageStore.parseDate(s) { return d }
            if let n = Double(s) { return Date(timeIntervalSince1970: n) }
            return nil
        }
        if let n = any as? Double { return Date(timeIntervalSince1970: n) }
        if let n = any as? Int { return Date(timeIntervalSince1970: Double(n)) }
        return nil
    }
}

// MARK: - Cache (graceful degradation)

public enum LiveLimitsCache {
    public static func save(_ live: LiveLimits) {
        SupportDir.ensure()
        if let data = try? HeadroomJSON.encoder.encode(live) {
            try? data.write(to: SupportDir.liveJSON)
        }
    }

    public static func load() -> LiveLimits? {
        guard let data = try? Data(contentsOf: SupportDir.liveJSON) else { return nil }
        return try? HeadroomJSON.decoder.decode(LiveLimits.self, from: data)
    }

    static let maxCacheAge: TimeInterval = 24 * 3600

    /// Returns `fresh` if present (and persists it); otherwise the last cached value,
    /// but only if it is recent and its windows have not already reset. Stale or
    /// reset-passed data is dropped so the UI never shows old numbers as current.
    public static func freshest(_ fresh: LiveLimits?, now: Date = Date()) -> LiveLimits? {
        if let fresh { save(fresh); return fresh }
        guard var cached = load(), now.timeIntervalSince(cached.capturedAt) < maxCacheAge else { return nil }
        cached.source = "cache"
        if let r = cached.fiveHour?.resetsAt, r < now { cached.fiveHour = nil }
        if let r = cached.sevenDay?.resetsAt, r < now { cached.sevenDay = nil }
        guard cached.fiveHour != nil || cached.sevenDay != nil else { return nil }
        return cached
    }
}
