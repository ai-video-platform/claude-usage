import Foundation

/// Well-known locations inside ~/.claude.
public enum ClaudePaths {
    public static var home: URL {
        #if os(macOS)
        // The CLI (unsandboxed) gets the real home; a sandboxed app gets its
        // container until the user grants access via a security-scoped bookmark.
        return FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".claude", isDirectory: true)
        #else
        // iOS / iPadOS / visionOS / watchOS have no ~/.claude. This path simply
        // will not exist, so loadRecords() returns []; those devices get data via sync.
        return URL(fileURLWithPath: NSHomeDirectory(), isDirectory: true)
            .appendingPathComponent(".claude", isDirectory: true)
        #endif
    }
    public static var projects: URL { home.appendingPathComponent("projects", isDirectory: true) }
    public static var statsCache: URL { home.appendingPathComponent("stats-cache.json") }

    /// Claude Code encodes a project's absolute path by replacing "/" with "-".
    /// We can't perfectly invert that, but the trailing component is the useful label.
    public static func projectLabel(fromDir dir: String) -> String {
        let trimmed = dir.hasPrefix("-") ? String(dir.dropFirst()) : dir
        let parts = trimmed.split(separator: "-").map(String.init)
        return parts.last ?? dir
    }
}

// MARK: - Raw JSONL decoding (only the fields we need)

private struct RawLine: Decodable {
    let type: String?
    let requestId: String?
    let timestamp: String?
    let message: RawMessage?
}
private struct RawMessage: Decodable {
    let model: String?
    let usage: RawUsage?
}
private struct RawUsage: Decodable {
    let input_tokens: Int?
    let output_tokens: Int?
    let cache_read_input_tokens: Int?
    let cache_creation_input_tokens: Int?
    let cache_creation: RawCacheCreation?
}
private struct RawCacheCreation: Decodable {
    let ephemeral_5m_input_tokens: Int?
    let ephemeral_1h_input_tokens: Int?
}

public struct UsageStore {
    public init() {}

    /// Per-file parsed-records cache so a refresh only re-parses changed files.
    struct CachedFile: Codable, Sendable {
        var mtime: Double
        var size: Int
        var records: [UsageRecord]
    }

    /// Scans every project transcript and returns deduplicated usage records.
    /// Unchanged files (same mtime + size) are served from a persisted cache, so the
    /// steady-state refresh is fast instead of re-reading every JSONL each time.
    public func loadRecords(projectsDir: URL = ClaudePaths.projects) -> [UsageRecord] {
        let fm = FileManager.default
        guard let projectDirs = try? fm.contentsOfDirectory(
            at: projectsDir, includingPropertiesForKeys: [.isDirectoryKey]) else { return [] }

        let cache = Self.loadScanCache(for: projectsDir)
        var nextCache: [String: CachedFile] = [:]

        // Keyed by requestId, keeping the record with the most tokens (deterministic
        // dedup of duplicate streaming lines, robust to partial-then-final usage).
        var byId: [String: UsageRecord] = [:]
        func merge(_ records: [UsageRecord]) {
            for rec in records {
                if let existing = byId[rec.requestId], existing.billedTokens >= rec.billedTokens { continue }
                byId[rec.requestId] = rec
            }
        }

        for dir in projectDirs {
            let isDir = (try? dir.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false
            guard isDir else { continue }
            let projectLabel = ClaudePaths.projectLabel(fromDir: dir.lastPathComponent)
            guard let files = try? fm.contentsOfDirectory(
                at: dir, includingPropertiesForKeys: [.contentModificationDateKey, .fileSizeKey])
            else { continue }

            for file in files where file.pathExtension == "jsonl" {
                let path = file.path
                let vals = try? file.resourceValues(forKeys: [.contentModificationDateKey, .fileSizeKey])
                let mtime = vals?.contentModificationDate?.timeIntervalSince1970 ?? 0
                let size = vals?.fileSize ?? 0

                if let cached = cache[path], cached.mtime == mtime, cached.size == size {
                    nextCache[path] = cached
                    merge(cached.records)
                    continue
                }
                let sessionId = file.deletingPathExtension().lastPathComponent
                let records = Self.parseFile(at: file, projectLabel: projectLabel, sessionId: sessionId)
                nextCache[path] = CachedFile(mtime: mtime, size: size, records: records)
                merge(records)
            }
        }
        Self.saveScanCache(nextCache, for: projectsDir)
        return Array(byId.values)
    }

    /// Parses a single JSONL transcript into usage records (synthetic models excluded).
    static func parseFile(at file: URL, projectLabel: String, sessionId: String) -> [UsageRecord] {
        guard let data = try? Data(contentsOf: file) else { return [] }
        let decoder = JSONDecoder()
        let newline = UInt8(0x0A)
        let usageNeedle = Array("\"usage\"".utf8)
        var out: [UsageRecord] = []

        var idx = data.startIndex
        while idx < data.endIndex {
            let end = data[idx...].firstIndex(of: newline) ?? data.endIndex
            let line = data[idx..<end]
            idx = end < data.endIndex ? data.index(after: end) : data.endIndex
            if line.isEmpty { continue }
            if line.firstRange(of: usageNeedle) == nil { continue }

            guard let raw = try? decoder.decode(RawLine.self, from: Data(line)),
                  raw.type == "assistant",
                  let usage = raw.message?.usage,
                  let model = raw.message?.model,
                  let reqId = raw.requestId
            else { continue }
            // Skip Claude Code's internal synthetic models (title/quota helpers).
            if model.lowercased().contains("synthetic") { continue }

            let c5 = usage.cache_creation?.ephemeral_5m_input_tokens ?? 0
            let c1h = usage.cache_creation?.ephemeral_1h_input_tokens ?? 0
            let cTotal = usage.cache_creation_input_tokens ?? 0
            let cOther = max(0, cTotal - c5 - c1h)
            let ts = raw.timestamp.flatMap(Self.parseDate) ?? Date(timeIntervalSince1970: 0)

            out.append(UsageRecord(
                requestId: reqId, model: model, timestamp: ts,
                inputTokens: usage.input_tokens ?? 0, outputTokens: usage.output_tokens ?? 0,
                cacheCreate5m: c5, cacheCreate1h: c1h, cacheCreateOther: cOther,
                cacheReadTokens: usage.cache_read_input_tokens ?? 0,
                project: projectLabel, sessionId: sessionId))
        }
        return out
    }

    // Cache is keyed to the projects dir so the CLI and a custom dir don't collide.
    // Uses a process-stable hash (String.hashValue is randomized per run, which would
    // defeat the cache across launches).
    private static func stableTag(_ s: String) -> String {
        var hash: UInt64 = 14695981039346656037   // FNV-1a offset basis
        for byte in s.utf8 { hash = (hash ^ UInt64(byte)) &* 1099511628211 }
        return String(hash, radix: 36)
    }
    private static func scanCacheURL(for projectsDir: URL) -> URL {
        SupportDir.url.appendingPathComponent("scan-cache-\(stableTag(projectsDir.path)).json")
    }
    static func loadScanCache(for projectsDir: URL) -> [String: CachedFile] {
        guard let data = try? Data(contentsOf: scanCacheURL(for: projectsDir)) else { return [:] }
        return (try? JSONDecoder().decode([String: CachedFile].self, from: data)) ?? [:]
    }
    static func saveScanCache(_ cache: [String: CachedFile], for projectsDir: URL) {
        SupportDir.ensure()
        if let data = try? JSONEncoder().encode(cache) {
            try? data.write(to: scanCacheURL(for: projectsDir))
        }
    }

    /// Folds records into per-model, per-project, per-day, and overall totals.
    public func aggregate(_ records: [UsageRecord], calendar: Calendar = .current) -> UsageReport {
        var report = UsageReport()
        let dayFmt = DateFormatter()
        dayFmt.dateFormat = "yyyy-MM-dd"
        dayFmt.calendar = calendar
        dayFmt.timeZone = calendar.timeZone

        for r in records {
            let t = r.tokenTotals
            report.overall.add(t)
            report.byModel[ModelFamily.token(for: r.model), default: TokenTotals()].add(t)
            report.byProject[r.project, default: TokenTotals()].add(t)
            report.byDay[dayFmt.string(from: r.timestamp), default: TokenTotals()].add(t)
            report.sessions.insert(r.sessionId)
            if report.firstSeen == nil || r.timestamp < report.firstSeen! { report.firstSeen = r.timestamp }
            if report.lastSeen == nil || r.timestamp > report.lastSeen! { report.lastSeen = r.timestamp }
        }
        return report
    }

    /// Sums records whose timestamp falls inside [since, until].
    public func window(_ records: [UsageRecord], since: Date, until: Date) -> TokenTotals {
        var t = TokenTotals()
        for r in records where r.timestamp >= since && r.timestamp <= until {
            t.add(r.tokenTotals)
        }
        return t
    }

    // ISO8601 parsing, with and without fractional seconds. Created per call (single-threaded scan).
    static func parseDate(_ s: String) -> Date? {
        let withFrac = ISO8601DateFormatter()
        withFrac.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = withFrac.date(from: s) { return d }
        let plain = ISO8601DateFormatter()
        plain.formatOptions = [.withInternetDateTime]
        return plain.date(from: s)
    }
}
