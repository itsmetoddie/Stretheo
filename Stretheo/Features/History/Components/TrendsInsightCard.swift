//
//  TrendsInsightCard.swift
//  Stretheo
//
//  Trends & Insights — top correlations in plain language.
//

import SwiftUI

struct TrendsInsightCard: View {
    let insights: [Insight]
    let isReady: Bool

    private var isPlaceholderEmptyState: Bool {
        insights.count == 1 && insights.first?.confidence == 0
    }

    var body: some View {
        Group {
            if isReady, !insights.isEmpty {
                cardContent
            }
        }
    }

    private var cardContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionHeaderView(
                systemImage: "sparkles",
                title: String(localized: "history.trends.title")
            )

            Group {
                if isPlaceholderEmptyState, let insight = insights.first {
                    Text(insight.title)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else if insights.count == 1, let insight = insights.first {
                    insightPage(insight)
                } else {
                    TabView {
                        ForEach(insights) { insight in
                            insightPage(insight)
                                .padding(.horizontal, AppSpacing.xxs)
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: .automatic))
                    .frame(minHeight: 148)
                }
            }
            .padding(.horizontal, AppSpacing.md)
            .padding(.bottom, AppSpacing.md)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .homeScreenCard(padding: 0)
    }

    private func insightPage(_ insight: Insight) -> some View {
        HStack(alignment: .top, spacing: AppSpacing.md) {
            Image(systemName: insight.icon)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(width: 20, alignment: .leading)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                Text(insight.title)
                    .font(.headline)
                    .fixedSize(horizontal: false, vertical: true)

                Text(insight.body)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}
