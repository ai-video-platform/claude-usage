//
//  ProjectDetailView.swift
//  Claude Usage
//

import SwiftUI
import HeadroomCore

struct ProjectDetailView: View {
    let projects: [ProjectStat]
    @Environment(\.dismiss) private var dismiss
    private var maxCost: Double { projects.map(\.costUSD).max() ?? 1 }

    var body: some View {
        VStack(spacing: 0) {
            // In-content header (the menu bar popover has no navigation chrome for a Back button).
            HStack(spacing: 12) {
                Button { dismiss() } label: { Image(systemName: "chevron.left") }
                    .glassButton().foregroundStyle(Theme.accent).accessibilityLabel("Back")
                Text("Projects").font(.title2.bold()).foregroundStyle(Theme.ink)
                Spacer()
            }
            .font(.title3)
            .padding(.horizontal, 16).padding(.top, 12).padding(.bottom, 8)

            ScrollView {
                VStack(spacing: 10) {
                    ForEach(projects, id: \.name) { p in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(alignment: .firstTextBaseline) {
                                Text(p.name).font(.subheadline.weight(.medium)).foregroundStyle(Theme.ink)
                                Spacer()
                                Text(Fmt.usd(p.costUSD))
                                    .font(.subheadline.monospacedDigit().weight(.semibold)).foregroundStyle(Theme.ink)
                                Text(Fmt.tok(p.totalTokens))
                                    .font(.caption.monospacedDigit()).foregroundStyle(Theme.inkTertiary)
                                    .frame(width: 58, alignment: .trailing)
                            }
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    Capsule().fill(.white.opacity(0.08))
                                    Capsule().fill(Theme.accent)
                                        .frame(width: geo.size.width * (maxCost > 0 ? p.costUSD / maxCost : 0))
                                }
                            }
                            .frame(height: 6)
                        }
                        .glassCard(padding: 12)
                    }
                }
                .padding(16)
                .frame(maxWidth: 560)
                .frame(maxWidth: .infinity)
            }
        }
        .background(Theme.background)
        #if os(iOS)
        .toolbar(.hidden, for: .navigationBar)
        #endif
    }
}
