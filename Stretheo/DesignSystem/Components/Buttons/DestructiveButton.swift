//
//  DestructiveButton.swift
//  Stretheo
//

import SwiftUI

/// Destructive actions — Clear All Data, Delete Account (Figma red text).
struct DestructiveButton: View {
    let title: String
    var systemImage: String?
    var style: Style = .text
    let action: () -> Void

    enum Style {
        case text
        case filled
    }

    init(
        title: String,
        systemImage: String? = nil,
        style: Style = .text,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.systemImage = systemImage
        self.style = style
        self.action = action
    }

    var body: some View {
        Button(role: .destructive, action: action) {
            HStack(spacing: AppSpacing.xs) {
                if let systemImage {
                    Image(systemName: systemImage)
                }
                Text(title)
                    .font(AppTypography.headline)
            }
            .frame(maxWidth: .infinity)
            .frame(minHeight: AppSpacing.minTouchTarget)
            .foregroundStyle(foregroundColor)
            .background(backgroundColor, in: RoundedRectangle(cornerRadius: AppRadius.button, style: .continuous))
            .overlay {
                if style == .text {
                    RoundedRectangle(cornerRadius: AppRadius.button, style: .continuous)
                        .strokeBorder(AppColors.destructive.opacity(0.25), lineWidth: 1)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
    }

    private var foregroundColor: Color {
        style == .filled ? AppColors.textOnPrimary : AppColors.destructive
    }

    private var backgroundColor: Color {
        style == .filled ? AppColors.destructive : AppColors.cardSurface
    }
}

#Preview {
    VStack(spacing: AppSpacing.md) {
        DestructiveButton(title: "Clear All Data", systemImage: "trash", action: {})
        DestructiveButton(title: "Delete Account", style: .filled, action: {})
    }
    .padding()
}
