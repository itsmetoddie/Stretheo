//
//  LiquidGlassSurface.swift
//  Stretheo
//
//  Layered Liquid Glass surfaces — uniform corner radius on all four corners (required for glass).
//  Stretheo targets iOS 26; iOS 27 adds scroll-responsive glass intensity not adopted here.
//

import SwiftUI

enum LiquidGlassMetrics {
    static let sheetCornerRadius: CGFloat = 28
    static let cardCornerRadius: CGFloat = HomeScreenCardStyle.cornerRadius
    static let topHighlightOpacity: Double = 0.08
    static let hairlineOpacity: Double = 0.3
    static let accentBarWidth: CGFloat = 2
    static let cardShadow = ShadowStyle(color: Color.black.opacity(0.04), radius: 6, y: 2)
}

/// System sheet material with a subtle top-edge highlight (lit-from-above).
struct LiquidGlassSheetBackground: View {
    var cornerRadius: CGFloat = LiquidGlassMetrics.sheetCornerRadius

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        shape
            .fill(.ultraThinMaterial)
            .overlay {
                shape.strokeBorder(topHighlightGradient, lineWidth: 1)
            }
    }

    private var topHighlightGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color.white.opacity(LiquidGlassMetrics.topHighlightOpacity),
                Color.white.opacity(LiquidGlassMetrics.topHighlightOpacity * 0.25),
                Color.clear
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}

/// Glass notification row — neutral hairline, stress accent on leading bar only.
struct LiquidGlassAccentCardBackground: View {
    let accentColor: Color
    var isMuted: Bool = false
    var cornerRadius: CGFloat = LiquidGlassMetrics.cardCornerRadius

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        shape
            .fill(.ultraThinMaterial)
            .overlay {
                shape.fill(accentColor.opacity(isMuted ? 0.03 : 0.07))
            }
            .overlay(alignment: .leading) {
                Capsule()
                    .fill(accentColor)
                    .frame(width: LiquidGlassMetrics.accentBarWidth)
                    .padding(.vertical, 10)
            }
            .overlay {
                shape.strokeBorder(
                    Color(.separator).opacity(LiquidGlassMetrics.hairlineOpacity),
                    lineWidth: 0.5
                )
            }
    }
}
