//
//  AppSwitcherPrivacyOverlay.swift
//  Stretheo
//
//  Covers sensitive health UI in the iOS app switcher / multitasking snapshot.
//

import SwiftUI

/// Shown while the scene is not `.active` so stress/HRV values are not visible in the app switcher.
struct AppSwitcherPrivacyOverlay: View {
    var body: some View {
        ZStack {
            AppColors.appBackground
                .ignoresSafeArea()

            VStack(spacing: AppSpacing.md) {
                Image("LaunchIcon")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 96, height: 96)
                    .accessibilityHidden(true)

                Text("Stretheo")
                    .font(AppTypography.sectionTitle)
                    .foregroundStyle(AppColors.textPrimary)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Stretheo")
    }
}
