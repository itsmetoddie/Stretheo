//
//  ArticleRowView.swift
//  Stretheo
//

import SwiftUI

struct ArticleRowView: View {
    let article: Article

    private let iconSize: CGFloat = 52
    private let iconCornerRadius: CGFloat = 12
    private let minRowHeight: CGFloat = 72
    var body: some View {
        HStack(alignment: .center, spacing: AppSpacing.md) {
            Image(systemName: articleIconName)
                .font(.title3)
                .foregroundStyle(.white)
                .frame(width: iconSize, height: iconSize)
                .background(
                    AppColors.articleIconColor(category: article.category),
                    in: RoundedRectangle(cornerRadius: iconCornerRadius, style: .continuous)
                )

            VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                Text(article.title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Text(article.summary)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .truncationMode(.tail)
            }

            Spacer(minLength: 0)

            Image(systemName: "chevron.right")
                .font(.body.weight(.semibold))
                .foregroundStyle(Color(.tertiaryLabel))
                .accessibilityHidden(true)
        }
        .frame(minHeight: minRowHeight)
        .padding(.vertical, AppSpacing.xs)
    }

    private var articleIconName: String {
        AppColors.articleIconName(category: article.category)
    }
}
