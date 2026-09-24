//
//  ErrorBannerView.swift
//  Stretheo
//

import SwiftUI

struct ErrorBannerView: View {
    let message: String
    @Binding var isPresented: Bool
    var onDismiss: (() -> Void)?

    var body: some View {
        HStack(spacing: AppSpacing.sm) {
            Image(systemName: "exclamationmark.triangle.fill")
            Text(message)
                .font(AppTypography.label)
                .lineLimit(3)
            Spacer(minLength: 0)
            Button {
                isPresented = false
                onDismiss?()
            } label: {
                Image(systemName: "xmark.circle.fill")
            }
            .accessibilityLabel(String(localized: "error.banner.dismiss"))
        }
        .foregroundStyle(.white)
        .padding(AppSpacing.md)
        .background(AppColors.stressHigh, in: RoundedRectangle(cornerRadius: AppRadius.inner, style: .continuous))
        .padding(.horizontal, AppSpacing.md)
    }
}
