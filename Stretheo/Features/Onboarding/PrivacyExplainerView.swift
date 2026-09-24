//
//  PrivacyExplainerView.swift
//  Stretheo
//

import SwiftUI

struct PrivacyExplainerView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.lg) {
                VStack(alignment: .leading, spacing: AppSpacing.sm) {
                    Text(String(localized: "onboarding.privacy.title"))
                        .font(AppTypography.screenTitle)
                    Text(String(localized: "onboarding.privacy.body"))
                        .font(AppTypography.body)
                        .foregroundStyle(AppColors.textSecondary)
                }

                VStack(spacing: AppSpacing.sm) {
                    PrivacyPointCard(
                        icon: "lock.shield.fill",
                        title: String(localized: "onboarding.privacy.point1.title"),
                        detail: String(localized: "onboarding.privacy.point1")
                    )
                    PrivacyPointCard(
                        icon: "iphone.gen3",
                        title: String(localized: "onboarding.privacy.point2.title"),
                        detail: String(localized: "onboarding.privacy.point2")
                    )
                    PrivacyPointCard(
                        icon: "icloud.slash.fill",
                        title: String(localized: "onboarding.privacy.point3.title"),
                        detail: String(localized: "onboarding.privacy.point3")
                    )
                    PrivacyPointCard(
                        icon: "hand.raised.fill",
                        title: String(localized: "onboarding.privacy.point4.title"),
                        detail: String(localized: "onboarding.privacy.point4")
                    )
                }
            }
            .padding(AppSpacing.lg)
        }
    }
}

private struct PrivacyPointCard: View {
    let icon: String
    let title: String
    let detail: String

    var body: some View {
        HStack(alignment: .top, spacing: AppSpacing.md) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(AppColors.appPrimary)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                Text(title)
                    .font(AppTypography.sectionTitle)
                Text(detail)
                    .font(AppTypography.body)
                    .foregroundStyle(AppColors.textSecondary)
            }
            Spacer(minLength: 0)
        }
        .homeScreenCard(padding: AppSpacing.md)
    }
}
