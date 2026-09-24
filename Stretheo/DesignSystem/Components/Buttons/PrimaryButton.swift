//
//  PrimaryButton.swift
//  Stretheo
//

import SwiftUI

/// Full-width primary CTA — Figma blue pill ("Measure Now", "Start", "Save Mood").
struct PrimaryButton: View {
    let title: String
    var systemImage: String?
    var isLoading: Bool = false
    var isEnabled: Bool = true
    let action: () -> Void

    init(
        title: String,
        systemImage: String? = nil,
        isLoading: Bool = false,
        isEnabled: Bool = true,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.systemImage = systemImage
        self.isLoading = isLoading
        self.isEnabled = isEnabled
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: AppSpacing.xs) {
                if isLoading {
                    SwiftUILoadingSpinner(tint: AppColors.textOnPrimary)
                } else if let systemImage {
                    Image(systemName: systemImage)
                        .font(AppTypography.headline)
                }
                Text(title)
                    .font(AppTypography.headline)
            }
            .frame(maxWidth: .infinity)
            .frame(minHeight: AppSpacing.minTouchTarget)
            .padding(.vertical, AppSpacing.xs)
            .foregroundStyle(AppColors.textOnPrimary)
            .background(AppColors.appPrimary, in: RoundedRectangle(cornerRadius: AppRadius.button, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled || isLoading)
        .opacity(isEnabled ? 1 : 0.5)
        .accessibilityLabel(title)
    }
}

#Preview {
    VStack(spacing: AppSpacing.md) {
        PrimaryButton(title: "Measure Now", action: {})
        PrimaryButton(title: "Start", systemImage: "play.fill", action: {})
        PrimaryButton(title: "Loading", isLoading: true, action: {})
    }
    .padding()
}
