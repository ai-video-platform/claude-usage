//
//  OnboardingView.swift
//  Claude Usage
//
//  A short, native feeling three step intro: name the pain, prove it is private,
//  then earn the sign in. Apple style feature rows, a pinned bottom bar, and a
//  prominent Liquid Glass call to action.
//

import SwiftUI

struct OnboardingView: View {
    @Bindable var model: UsageModel
    @State private var step = Int(ProcessInfo.processInfo.environment["CU_ONB"] ?? "0") ?? 0
    @State private var showConnect = false

    private let lastStep = 2

    var body: some View {
        TabView(selection: $step) {
            problemPage.tag(0)
            privacyPage.tag(1)
            setupPage.tag(2)
        }
        #if os(iOS)
        .tabViewStyle(.page(indexDisplayMode: .never))
        #endif
        .background(backdrop)
        .safeAreaInset(edge: .bottom) { bottomBar }
        .overlay(alignment: .topTrailing) {
            if step < lastStep {
                Button("Skip") { withAnimation { step = lastStep } }
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

    // MARK: Pages

    private var problemPage: some View {
        OnboardingPage(
            hero: { UsageHero(percent: 96, color: Theme.healthDanger, caption: "96% used") },
            title: "Stop hitting the wall by surprise",
            subtitle: "Claude's limits are invisible until you slam into them. Then you wait, with no idea for how long."
        ) {
            FeatureRow("bell.slash.fill", "No warning",
                       "You get cut off mid task, with no heads up.")
            FeatureRow("questionmark.circle.fill", "No idea when it is back",
                       "Was that a five hour wait, or a whole week?")
            FeatureRow("bolt.slash.fill", "Opus runs dry first",
                       "Your best model vanishes right when you need it.")
        }
    }

    private var privacyPage: some View {
        OnboardingPage(
            hero: { SymbolHero("lock.shield.fill", tint: Theme.healthSafe) },
            title: "Yours alone. Truly private.",
            subtitle: "No account to create. No servers to trust. Your usage never leaves this device."
        ) {
            FeatureRow("lock.fill", "You sign in on Claude's page",
                       "The app never sees your password.")
            FeatureRow("hand.raised.fill", "Nothing leaves your device",
                       "No servers, no analytics, no sharing.")
            FeatureRow("key.fill", "Stored in your Keychain",
                       "Your session is locked to this device.")
        }
    }

    private var setupPage: some View {
        OnboardingPage(
            hero: { UsageHero(percent: 62, color: Theme.accent, caption: "62% used") },
            title: "Your Claude limits, at a glance",
            subtitle: "Your 5 hour and weekly usage, when it resets, and your credits, everywhere you look."
        ) {
            FeatureRow("gauge.with.needle", "Know how much is left",
                       "Live 5 hour and weekly usage.")
            FeatureRow("clock.arrow.circlepath", "Know when it resets",
                       "Exact reset times for every limit.")
            FeatureRow("chart.line.uptrend.xyaxis", "See if you are on pace",
                       "A simple ahead or behind read.")
            FeatureRow("bell.badge.fill", "Get warned early",
                       "A nudge before you hit a limit.")
        }
    }

    // MARK: Bottom bar

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

            if step < lastStep {
                Button { withAnimation { step += 1 } } label: {
                    Text("Continue").font(.headline).frame(maxWidth: .infinity)
                }
                .glassProminentButton().controlSize(.large).tint(Theme.accent)
            } else {
                Label("You sign in on Claude's own page. We never see your password.",
                      systemImage: "lock.fill")
                    .font(.caption).foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                Button { showConnect = true } label: {
                    Text("Sign in to Claude").font(.headline).frame(maxWidth: .infinity)
                }
                .glassProminentButton().controlSize(.large).tint(Theme.accent)
                Text("Pro and Max plans. Team, Enterprise, and Google sign in are not supported.")
                    .font(.caption2).foregroundStyle(.secondary).multilineTextAlignment(.center)
                Text("An independent app. Not affiliated with or endorsed by Anthropic.")
                    .font(.caption2).foregroundStyle(.tertiary).multilineTextAlignment(.center)
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
                VStack(alignment: .leading, spacing: 20) {
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

/// Apple style feature row: symbol in the accent, title, and a one line subtitle.
private struct FeatureRow: View {
    let symbol: String
    let title: String
    let subtitle: String
    init(_ symbol: String, _ title: String, _ subtitle: String) {
        self.symbol = symbol; self.title = title; self.subtitle = subtitle
    }
    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: symbol)
                .font(.title2)
                .foregroundStyle(Theme.accent)
                .frame(width: 34, alignment: .center)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline)
                Text(subtitle).font(.subheadline).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
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
