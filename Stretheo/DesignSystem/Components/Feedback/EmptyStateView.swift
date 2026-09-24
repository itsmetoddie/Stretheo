//
//  EmptyStateView.swift
//  Stretheo
//

import SwiftUI

struct EmptyStateView: View {
    let title: String
    let message: String
    let systemImage: String

    var body: some View {
        VStack(spacing: AppSpacing.md) {
            Image(systemName: systemImage)
                .font(AppTypography.displayIcon)
                .foregroundStyle(AppColors.appAccent)
                .symbolEffect(.pulse, options: .repeating)
            Text(title)
                .font(AppTypography.sectionTitle)
            Text(message)
                .font(AppTypography.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(AppSpacing.xl)
    }
}

/// Compact empty state used inside home-screen cards (icon + title + optional hint).
struct CardInlineEmptyState: View {
    let systemImage: String
    let title: String
    var hint: String?

    var body: some View {
        VStack(spacing: AppSpacing.xs) {
            Image(systemName: systemImage)
                .font(.system(size: 28))
                .foregroundStyle(.secondary)
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            if let hint, !hint.isEmpty {
                Text(hint)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
    }
}
