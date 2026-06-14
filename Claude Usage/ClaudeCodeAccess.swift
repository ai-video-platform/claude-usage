//
//  ClaudeCodeAccess.swift
//  Claude Usage
//
//  macOS only. Manages an opt in, revocable security scoped bookmark to the
//  user's Claude folder so we can read the local Claude Code logs. Nothing is
//  sent anywhere; the engine that parses the logs lives in HeadroomCore.
//

#if os(macOS)
import Foundation
import AppKit
import Combine
import HeadroomCore

@MainActor
final class ClaudeCodeAccess: ObservableObject {
    @Published var enabled: Bool
    private let key = "ccBookmark"

    init() { enabled = UserDefaults.standard.data(forKey: key) != nil }

    /// Ask the user to grant access to their Claude folder, then store a bookmark.
    func requestAccess() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.showsHiddenFiles = true
        panel.prompt = "Grant access"
        panel.message = "Choose your Claude folder (.claude in your home folder) so we can read your Claude Code logs."
        let claude = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".claude")
        if FileManager.default.fileExists(atPath: claude.path) { panel.directoryURL = claude }

        guard panel.runModal() == .OK, let url = panel.url,
              let data = try? url.bookmarkData(options: .withSecurityScope,
                                               includingResourceValuesForKeys: nil, relativeTo: nil)
        else { return }
        UserDefaults.standard.set(data, forKey: key)
        enabled = true
    }

    func revoke() {
        UserDefaults.standard.removeObject(forKey: key)
        enabled = false
    }

    /// Resolve the bookmark, read the logs, and build the stats. Does file IO,
    /// so call it off the main actor.
    nonisolated func loadStats() -> UsageSnapshot? {
        guard let data = UserDefaults.standard.data(forKey: "ccBookmark") else { return nil }
        var stale = false
        guard let url = try? URL(resolvingBookmarkData: data, options: .withSecurityScope,
                                 relativeTo: nil, bookmarkDataIsStale: &stale) else { return nil }
        guard url.startAccessingSecurityScopedResource() else { return nil }
        defer { url.stopAccessingSecurityScopedResource() }
        let projects = url.lastPathComponent == "projects" ? url : url.appendingPathComponent("projects")
        let records = UsageStore().loadRecords(projectsDir: projects)
        guard !records.isEmpty else { return nil }
        return SnapshotBuilder().build(records: records, live: nil)
    }
}
#endif
