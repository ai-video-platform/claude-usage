//
//  ConnectClaudeView.swift
//  Claude Usage
//
//  Signs in to Claude on Anthropic's own page (email + verification code) and
//  captures the resulting session cookie. The key is stored only in the Keychain.
//

#if canImport(WebKit)
import SwiftUI
import Combine
import WebKit

@MainActor
final class ClaudeLoginModel: NSObject, ObservableObject, WKNavigationDelegate, WKHTTPCookieStoreObserver {
    let webView: WKWebView
    var onSessionKey: ((String) -> Void)?
    @Published var status = "Sign in with the email you use for claude.ai."
    private var captured = false
    private var pollTask: Task<Void, Never>?

    override init() {
        webView = WKWebView(frame: .zero, configuration: WKWebViewConfiguration())
        super.init()
        webView.navigationDelegate = self
        let store = webView.configuration.websiteDataStore   // default store (reliable cookie reads)
        store.httpCookieStore.add(self)
        // Fresh login: clear any existing Claude session first, then load the login page.
        store.httpCookieStore.getAllCookies { [weak self] cookies in
            let group = DispatchGroup()
            for c in cookies where Self.isClaude(c) {
                group.enter(); store.httpCookieStore.delete(c) { group.leave() }
            }
            group.notify(queue: .main) {
                guard let self, let url = URL(string: "https://claude.ai/login") else { return }
                self.webView.load(URLRequest(url: url))
            }
        }
    }

    private static func isClaude(_ c: HTTPCookie) -> Bool {
        c.domain.contains("claude.ai") || c.domain.contains("anthropic")
    }

    /// Actively poll the cookie store until the session key appears, then capture.
    /// This is more reliable than waiting on the cookie observer or didFinish alone
    /// (which missed the cookie on iPad), so the webview auto dismisses once signed in.
    func beginCapturing() {
        guard pollTask == nil else { return }
        pollTask = Task { @MainActor [weak self] in
            while let self, !Task.isCancelled, !self.captured {
                self.tryCapture()
                try? await Task.sleep(for: .milliseconds(800))
            }
        }
    }

    nonisolated func cookiesDidChange(in cookieStore: WKHTTPCookieStore) {
        Task { @MainActor in self.tryCapture() }
    }
    nonisolated func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        Task { @MainActor in
            self.tryCapture()
            if !self.captured, let url = self.webView.url,
               (url.host ?? "").contains("claude.ai"), !url.path.contains("login") {
                self.status = "Signing you in…"
            }
        }
    }

    /// Manual fallback: the user taps "Done" once claude.ai shows them signed in.
    func captureNow() { tryCapture(manual: true) }

    private func tryCapture(manual: Bool = false) {
        guard !captured, let deliver = onSessionKey else {
            if manual { status = "Just a moment…" }
            return
        }
        let store = webView.configuration.websiteDataStore
        store.httpCookieStore.getAllCookies { [weak self] cookies in
            guard let self, !self.captured else { return }
            guard let cookie = cookies.first(where: {
                $0.name == "sessionKey" && $0.domain.contains("claude.ai") && !$0.value.isEmpty
            }) else {
                if manual { self.status = "Not signed in yet. Finish signing in to Claude above, then tap Done." }
                return
            }
            self.captured = true
            self.pollTask?.cancel()
            self.status = "Signing you in…"
            let value = cookie.value
            // Remove the on-device web session now that we have the key, then finish.
            let group = DispatchGroup()
            for c in cookies where Self.isClaude(c) {
                group.enter(); store.httpCookieStore.delete(c) { group.leave() }
            }
            group.notify(queue: .main) { deliver(value) }
        }
    }
}

struct ClaudeWebViewRep {
    let model: ClaudeLoginModel
}
#if os(macOS)
extension ClaudeWebViewRep: NSViewRepresentable {
    func makeNSView(context: Context) -> WKWebView { model.webView }
    func updateNSView(_ view: WKWebView, context: Context) {}
}
#elseif os(iOS)
extension ClaudeWebViewRep: UIViewRepresentable {
    func makeUIView(context: Context) -> WKWebView { model.webView }
    func updateUIView(_ view: WKWebView, context: Context) {}
}
#endif

struct ConnectClaudeView: View {
    var onConnected: () -> Void
    @Environment(\.dismiss) private var dismiss
    @StateObject private var login = ClaudeLoginModel()

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button("Cancel") { dismiss() }
                Spacer()
                Text("Sign in to Claude").font(.headline).foregroundStyle(Theme.ink)
                Spacer()
                Button("Done") { login.captureNow() }.fontWeight(.semibold)
            }
            .padding()
            .background(Theme.bgTop)

            ClaudeWebViewRep(model: login)

            VStack(alignment: .leading, spacing: 6) {
                Label("This is Claude's official page. We never see your password.", systemImage: "lock.fill")
                    .font(.caption2).foregroundStyle(Theme.inkSecondary)
                Text(login.status)
                    .font(.caption).foregroundStyle(Theme.inkTertiary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(Theme.bgTop)
        }
        .tint(Theme.accent)
        #if os(macOS)
        .frame(minWidth: 460, minHeight: 640)
        #endif
        .onAppear {
            login.onSessionKey = { key in
                KeychainStore.set(key, account: KeychainStore.claudeSessionAccount)
                onConnected()
                dismiss()
            }
            login.beginCapturing()
        }
    }
}
#endif
