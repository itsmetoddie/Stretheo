//
//  ArticlesSearchBar.swift
//  Stretheo
//

import SwiftUI

struct ArticlesSearchBar: View {
    @Binding var text: String

    private let cornerRadius: CGFloat = 12
    private let fieldShadow = ShadowStyle(color: Color.black.opacity(0.06), radius: 8, y: 2)

    var body: some View {
        HStack(spacing: AppSpacing.sm) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)

            TextField(
                String(localized: "articles.search.placeholder"),
                text: $text
            )
            .textFieldStyle(.plain)
            .autocorrectionDisabled()
            .textInputAutocapitalization(.never)

            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(String(localized: "articles.search.clear"))
            }
        }
        .padding(.horizontal, AppSpacing.md)
        .padding(.vertical, AppSpacing.sm)
        .background(
            Color(.secondarySystemGroupedBackground),
            in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        )
        .stretheoShadow(fieldShadow)
    }
}
