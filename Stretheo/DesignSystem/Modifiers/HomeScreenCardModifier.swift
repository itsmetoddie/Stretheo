//
//  HomeScreenCardModifier.swift
//  Stretheo
//
//  Home tab card chrome — 16pt corners, grouped background, subtle elevation.
//

import SwiftUI

enum HomeScreenCardStyle {
    nonisolated static let cornerRadius: CGFloat = 16
    nonisolated static let shadow = ShadowStyle(color: Color.black.opacity(0.04), radius: 6, y: 2)

    nonisolated static var backgroundColor: Color {
        Color(.secondarySystemGroupedBackground)
    }
}

struct HomeScreenCardModifier: ViewModifier {
    var padding: CGFloat = AppSpacing.lg
    var elevated: Bool = true

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(
                HomeScreenCardStyle.backgroundColor,
                in: RoundedRectangle(cornerRadius: HomeScreenCardStyle.cornerRadius, style: .continuous)
            )
            .overlay {
                if !elevated {
                    RoundedRectangle(cornerRadius: HomeScreenCardStyle.cornerRadius, style: .continuous)
                        .strokeBorder(Color(.separator), lineWidth: 0.5)
                }
            }
            .modifier(HomeScreenCardElevationModifier(elevated: elevated))
    }
}

private struct HomeScreenCardElevationModifier: ViewModifier {
    let elevated: Bool

    func body(content: Content) -> some View {
        if elevated {
            content.stretheoShadow(HomeScreenCardStyle.shadow)
        } else {
            content
        }
    }
}

extension View {
    func homeScreenCard(padding: CGFloat = AppSpacing.lg, elevated: Bool = true) -> some View {
        modifier(HomeScreenCardModifier(padding: padding, elevated: elevated))
    }
}
