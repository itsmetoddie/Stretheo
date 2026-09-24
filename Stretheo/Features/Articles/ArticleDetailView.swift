//
//  ArticleDetailView.swift
//  Stretheo
//

import SwiftUI

struct ArticleDetailView: View {
    let article: Article

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                Text(article.category)
                    .font(AppTypography.metadata)
                    .foregroundStyle(AppColors.appAccent)
                HStack {
                    Text(article.author)
                    Text("·")
                    Text(article.publishedDate.formatted(date: .abbreviated, time: .omitted))
                }
                .font(AppTypography.metadata)
                .foregroundStyle(.secondary)
                Text(article.content)
                    .font(AppTypography.body)
            }
            .padding(AppSpacing.md)
        }
        .background(AppColors.appBackground)
        .navigationTitle(article.title)
        .navigationBarTitleDisplayMode(.inline)
    }
}
