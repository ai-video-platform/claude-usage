//
//  Theme.swift
//  Claude Usage
//
//  Dark, glass forward design system. Real Liquid Glass on
//  iOS 26 / macOS 26, with an ultraThinMaterial fallback on the iOS 17 / macOS 14
//  floor. Tokens follow the brand intent: warm charcoal, Claude clay accent,
//  traffic light health colors.
//

import SwiftUI

enum Theme {
    // Native system surfaces so the app adapts and feels first party.
    #if os(iOS)
    static let surface = Color(uiColor: .systemGroupedBackground)
    static let cardColor = Color(uiColor: .secondarySystemGroupedBackground)
    #else
    static let surface = Color(nsColor: .windowBackgroundColor)
    static let cardColor = Color(nsColor: .controlBackgroundColor)
    #endif

    // Kept for the menu bar glass and a couple of chrome tints.
    static let bgTop = Color(red: 0.059, green: 0.059, blue: 0.071)
    static let bgBottom = Color(red: 0.031, green: 0.031, blue: 0.039)
    static let stroke = Color.primary.opacity(0.08)

    // Ink: system semantic colors so contrast is always correct.
    static let ink = Color.primary
    static let inkSecondary = Color.secondary
    static let inkTertiary = Color.secondary.opacity(0.65)

    // Claude clay coral accent (CTA, active states, brand arc, links)
    static let accent = Color(red: 0.851, green: 0.467, blue: 0.341)   // #D97757

    // Pace marker tick
    static let pace = Color.white.opacity(0.7)

    // Health scale (traffic light), keyed by USED percent
    static let healthSafe = Color(red: 0.31, green: 0.827, blue: 0.494)    // #4FD37E
    static let healthCaution = Color(red: 1.0, green: 0.722, blue: 0.302)  // #FFB84D
    static let healthDanger = Color(red: 1.0, green: 0.42, blue: 0.42)     // #FF6B6B

    static func health(_ percent: Double) -> Color {
        switch percent {
        case ..<70: return healthSafe
        case ..<90: return healthCaution
        default:    return healthDanger
        }
    }
    static func healthGradient(_ percent: Double) -> LinearGradient {
        let c = health(percent)
        return LinearGradient(colors: [c.opacity(0.72), c], startPoint: .top, endPoint: .bottom)
    }

    // Shape
    static let cornerCard: CGFloat = 20
    static let cornerTile: CGFloat = 14

    /// The native system background, so the app looks first party and adapts.
    static var background: some View {
        surface.ignoresSafeArea()
    }
}

/// A glass card: real Liquid Glass where available, a translucent material otherwise.
struct GlassCard: ViewModifier {
    var radius: CGFloat = Theme.cornerCard
    var padding: CGFloat = 16

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.cardColor, in: .rect(cornerRadius: radius))
    }
}

extension View {
    func glassCard(radius: CGFloat = Theme.cornerCard, padding: CGFloat = 16) -> some View {
        modifier(GlassCard(radius: radius, padding: padding))
    }

    /// Native Liquid Glass prominent button on iOS 26 / macOS 26, with a bordered
    /// prominent fallback on the iOS 17 / macOS 14 floor.
    @ViewBuilder func glassProminentButton() -> some View {
        if #available(iOS 26.0, macOS 26.0, *) {
            buttonStyle(.glassProminent)
        } else {
            buttonStyle(.borderedProminent)
        }
    }

    /// Native Liquid Glass button, with a bordered fallback.
    @ViewBuilder func glassButton() -> some View {
        if #available(iOS 26.0, macOS 26.0, *) {
            buttonStyle(.glass)
        } else {
            buttonStyle(.bordered)
        }
    }
}

/// Section wrapper: a titled glass card (kept for reuse).
struct GlassSection<Content: View>: View {
    let title: String?
    var trailing: AnyView? = nil
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if title != nil || trailing != nil {
                HStack {
                    if let title {
                        Text(title.uppercased())
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Theme.inkTertiary)
                            .tracking(0.8)
                    }
                    Spacer()
                    trailing
                }
            }
            content
        }
        .glassCard()
    }
}

/// A small uppercase caption used as a group label inside cards.
struct CardCaption: View {
    let text: String
    var body: some View {
        Text(text.uppercased())
            .font(.caption2.weight(.semibold)).tracking(0.8)
            .foregroundStyle(Theme.inkTertiary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}
