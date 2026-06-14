//
//  OnboardingView.swift
//  Claude Usage
//
//  A short, native three step intro: name the pain, prove it is private and open
//  source, then earn the sign in. Apple style feature rows, a constant bottom bar
//  for smooth page transitions, and a prominent Liquid Glass call to action.
//

import SwiftUI

struct OnboardingView: View {
    @Bindable var model: UsageModel
    @State private var step = Int(ProcessInfo.processInfo.environment["CU_ONB"] ?? "0") ?? 0
    @State private var showConnect = false

    private let lastStep = 3

    var body: some View {
        TabView(selection: $step) {
            problemPage.tag(0)
            privacyPage.tag(1)
            openSourcePage.tag(2)
            setupPage.tag(3)
        }
        #if os(iOS)
        .tabViewStyle(.page(indexDisplayMode: .never))
        #endif
        .background(backdrop)
        .safeAreaInset(edge: .bottom) { bottomBar }
        .overlay(alignment: .topTrailing) {
            if step < lastStep {
                Button("Skip") { withAnimation(.smooth) { step = lastStep } }
                    .font(.body)
                    .padding(.horizontal, 20).padding(.top, 8)
            }
        }
        .tint(Theme.accent)
        .preferredColorScheme(.dark)
        #if canImport(WebKit)
        .sheet(isPresented: $showConnect) {
            ConnectClaudeView { model.markClaudeConnected() }
        }
        #endif
    }

    private func advance() {
        if step < lastStep { withAnimation(.smooth) { step += 1 } } else { showConnect = true }
    }

    // MARK: Pages

    private var problemPage: some View {
        OnboardingPage(
            hero: { UsageHero(percent: 96, color: Theme.healthDanger, caption: "96% used") },
            title: "Stop hitting limits blind",
            subtitle: "Claude's limits are invisible until you slam into them."
        ) {
            FeatureRow("bell.slash.fill", "No warning before you are cut off")
            FeatureRow("questionmark.circle.fill", "No idea when access returns")
            FeatureRow("bolt.slash.fill", "Opus runs out first")
        }
    }

    private var privacyPage: some View {
        OnboardingPage(
            hero: { SymbolHero("lock.shield.fill", tint: Theme.healthSafe) },
            title: "Private by default",
            subtitle: "No account, no servers, nothing leaves your device."
        ) {
            FeatureRow("lock.fill", "Sign in on Claude's own page")
            FeatureRow("hand.raised.fill", "Nothing leaves your device")
            FeatureRow("key.fill", "Session stays in your Keychain")
        }
    }

    private var openSourcePage: some View {
        OnboardingPage(
            hero: { SymbolHero("chevron.left.forwardslash.chevron.right", tint: Theme.accent) },
            title: "Open source",
            subtitle: "Every line is public. Read it, fork it, send a PR."
        ) {
            FeatureRow("checkmark.seal.fill", "Free, no in app purchases")
            FeatureRow("eye.fill", "Nothing hidden")
            FeatureRow("arrow.triangle.branch", "Issues and PRs welcome")
            Link(destination: AppInfo.repoURL) {
                Label("View on GitHub", systemImage: "arrow.up.right")
                    .font(.subheadline.weight(.semibold))
            }
            .tint(Theme.accent)
            .padding(.top, 4)
        }
    }

    private var setupPage: some View {
        OnboardingPage(
            hero: { UsageHero(percent: 62, color: Theme.accent, caption: "62% used") },
            title: "See it all at a glance",
            subtitle: "Session and weekly usage, resets, and credits."
        ) {
            FeatureRow("gauge.with.needle", "How much is left")
            FeatureRow("clock.arrow.circlepath", "When it resets")
            FeatureRow("chart.line.uptrend.xyaxis", "Whether you are on pace")
            FeatureRow("bell.badge.fill", "A heads up before you hit a limit")
            VStack(spacing: 4) {
                Text("Pro and Max plans only.")
                Text(AppInfo.disclaimer)
            }
            .font(.caption2).foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding(.top, 12)
        }
    }

    // MARK: Bottom bar (constant height for smooth transitions)

    private var bottomBar: some View {
        VStack(spacing: 16) {
            HStack(spacing: 7) {
                ForEach(0...lastStep, id: \.self) { i in
                    Capsule()
                        .fill(i == step ? Theme.accent : Color.secondary.opacity(0.35))
                        .frame(width: i == step ? 22 : 7, height: 7)
                        .animation(.snappy, value: step)
                }
            }
            Button(action: advance) {
                Text(step < lastStep ? "Continue" : "Sign in to Claude")
                    .font(.headline).frame(maxWidth: .infinity)
            }
            .glassProminentButton().controlSize(.large).tint(Theme.accent)

            if step == lastStep {
                Button("Preview with sample data") { model.loadDemo() }
                    .font(.subheadline).tint(Theme.accent)
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 16)
        .padding(.bottom, 12)
        .frame(maxWidth: 480)
        .frame(maxWidth: .infinity)
        .background(.bar)
    }

    private var backdrop: some View {
        ZStack {
            Color(Theme.surface)
            RadialGradient(colors: [Theme.accent.opacity(0.12), .clear],
                           center: .top, startRadius: 0, endRadius: 360)
        }
        .ignoresSafeArea()
    }
}

// MARK: - Reusable onboarding pieces

/// One onboarding page: hero, large title, subtitle, then a column of feature rows.
private struct OnboardingPage<Hero: View, Rows: View>: View {
    @ViewBuilder var hero: () -> Hero
    let title: String
    let subtitle: String
    @ViewBuilder var rows: () -> Rows

    init(@ViewBuilder hero: @escaping () -> Hero, title: String, subtitle: String,
         @ViewBuilder rows: @escaping () -> Rows) {
        self.hero = hero; self.title = title; self.subtitle = subtitle; self.rows = rows
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                hero().padding(.top, 24)
                VStack(spacing: 10) {
                    Text(title)
                        .font(.largeTitle.bold())
                        .multilineTextAlignment(.center)
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                VStack(alignment: .leading, spacing: 18) {
                    rows()
                }
                .padding(.top, 4)
            }
            .padding(.horizontal, 32)
            .frame(maxWidth: 460)
            .frame(maxWidth: .infinity)
            .padding(.bottom, 24)
        }
        .scrollBounceBehavior(.basedOnSize)
    }
}

/// Apple style feature row: a symbol in the accent, a title, and an optional subtitle.
private struct FeatureRow: View {
    let symbol: String
    let title: String
    var subtitle: String?
    init(_ symbol: String, _ title: String, _ subtitle: String? = nil) {
        self.symbol = symbol; self.title = title; self.subtitle = subtitle
    }
    var body: some View {
        HStack(alignment: subtitle == nil ? .center : .top, spacing: 16) {
            Image(systemName: symbol)
                .font(.title2)
                .foregroundStyle(Theme.accent)
                .frame(width: 34, alignment: .center)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline)
                if let subtitle {
                    Text(subtitle).font(.subheadline).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 0)
        }
    }
}

/// A branded usage ring hero (fixed color, no pace marker).
private struct UsageHero: View {
    let percent: Double
    let color: Color
    let caption: String
    var body: some View {
        VStack(spacing: 10) {
            ZStack {
                Circle().stroke(.white.opacity(0.10), style: StrokeStyle(lineWidth: 12, lineCap: .round))
                Circle().trim(from: 0, to: min(1, percent / 100))
                    .stroke(color, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .shadow(color: color.opacity(0.45), radius: 8)
                Text("\(Int(percent))%")
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .monospacedDigit()
            }
            .frame(width: 116, height: 116)
            Text(caption).font(.caption.weight(.medium)).foregroundStyle(color)
        }
    }
}

/// A large SF Symbol hero in a tinted circle.
private struct SymbolHero: View {
    let symbol: String
    let tint: Color
    init(_ symbol: String, tint: Color) { self.symbol = symbol; self.tint = tint }
    var body: some View {
        ZStack {
            Circle().fill(tint.opacity(0.15)).frame(width: 116, height: 116)
            Image(systemName: symbol)
                .font(.system(size: 50))
                .foregroundStyle(tint)
        }
    }
}

#Preview {
    OnboardingView(model: UsageModel())
}
