//
//  FeaturedArticleCard.swift
//  Stretheo
//

import SwiftUI

struct FeaturedArticleCard: View {
    let article: Article

    private var readTimeText: String {
        "\(article.estimatedReadingMinutes) min read"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionHeaderView(
                systemImage: "star.fill",
                title: String(localized: "articles.featured.title")
            )

            HStack(alignment: .center, spacing: AppSpacing.sm) {
                featuredArticleContent
                Image(systemName: "chevron.right")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.85))
                    .accessibilityHidden(true)
            }
            .padding(AppSpacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.indigo.opacity(0.45),
                                Color.indigo.opacity(0.25)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .padding(.horizontal, AppSpacing.md)
            .padding(.bottom, AppSpacing.md)
        }
        .homeScreenCard(padding: 0)
    }

    private var featuredArticleContent: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Image(systemName: "brain.head.profile")
                .font(.system(size: 32))
                .foregroundStyle(.white)
                .frame(width: 32, height: 32)

            Text(article.title)
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundStyle(.white)
                .multilineTextAlignment(.leading)

            Text(article.summary)
                .font(.subheadline)
                .foregroundStyle(Color.white.opacity(0.85))
                .lineLimit(2)

            HStack(spacing: AppSpacing.sm) {
                Text(article.category)
                    .font(.caption)
                    .foregroundStyle(Color.white.opacity(0.7))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        Color.white.opacity(0.12),
                        in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                    )

                Label(readTimeText, systemImage: "clock")
                    .font(.caption2)
                    .foregroundStyle(Color.white.opacity(0.65))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
