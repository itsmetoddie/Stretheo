//
//  AppColors.swift
//  Stretheo
//
//  Semantic palette — brand from Assets; stress/mood use UIKit system colours.
//  `nonisolated` on static colours — safe under Swift 6 default MainActor isolation.
//

import SwiftUI
import UIKit

enum AppColors {
    // MARK: - Brand (Asset Catalog)

    nonisolated static let appPrimary = Color("AppPrimary")
    nonisolated static let appBackground = Color("AppBackground")
    nonisolated static let appSurface = Color("AppSurface")
    nonisolated static let appOnPrimary = Color("AppOnPrimary")
    nonisolated static let appOnBackground = Color("AppOnBackground")
    nonisolated static let appAccent = Color("AppAccent")

    // MARK: - UIKit semantic (light/dark adaptive)

    nonisolated static let label = Color(uiColor: .label)
    nonisolated static let secondaryLabel = Color(uiColor: .secondaryLabel)
    nonisolated static let systemBackground = Color(uiColor: .systemBackground)
    nonisolated static let secondarySystemBackground = Color(uiColor: .secondarySystemBackground)
    nonisolated static let tertiarySystemFill = Color(uiColor: .tertiarySystemFill)
    nonisolated static let tertiarySystemBackground = Color(uiColor: .tertiarySystemBackground)
    nonisolated static let separator = Color(uiColor: .separator)
    nonisolated static let systemBlue = Color(uiColor: .systemBlue)
    nonisolated static let systemGreen = Color(uiColor: .systemGreen)
    nonisolated static let systemOrange = Color(uiColor: .systemOrange)
    nonisolated static let systemRed = Color(uiColor: .systemRed)
    nonisolated static let systemYellow = Color(uiColor: .systemYellow)
    nonisolated static let systemGray5 = Color(uiColor: .systemGray5)
    nonisolated static let systemGray6 = Color(uiColor: .systemGray6)

    // MARK: - Stress accents (system)

    nonisolated static let stressLow = stressColor(for: .low)
    nonisolated static let stressModerate = stressColor(for: .moderate)
    nonisolated static let stressHigh = stressColor(for: .high)

    // MARK: - Mood accents (system)

    nonisolated static let mood1 = moodColor(for: 1)
    nonisolated static let mood2 = moodColor(for: 2)
    nonisolated static let mood3 = moodColor(for: 3)
    nonisolated static let mood4 = moodColor(for: 4)
    nonisolated static let mood5 = moodColor(for: 5)

    // MARK: - Text (semantic)

    nonisolated static let textPrimary = label
    nonisolated static let textSecondary = secondaryLabel
    nonisolated static let textOnPrimary = appOnPrimary

    // MARK: - Adaptive surfaces

    nonisolated static let canvas = appBackground
    nonisolated static let cardSurface = appSurface

    nonisolated static let iconBadgeBackground = tertiarySystemBackground
    nonisolated static let tabBarActiveBackground = tertiarySystemFill

    nonisolated static let segmentInactiveBackground = systemGray6
    nonisolated static let segmentBorder = Color(uiColor: .separator).opacity(0.35)

    // MARK: - Featured article

    nonisolated static let featuredGradientStart = Color("FeaturedGradientStart")
    nonisolated static let featuredGradientEnd = Color("FeaturedGradientEnd")

    nonisolated static var featuredGradient: LinearGradient {
        LinearGradient(
            colors: [featuredGradientStart, featuredGradientEnd],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    // MARK: - Article category tiles

    nonisolated static let articleBreathing = Color(red: 0.20, green: 0.78, blue: 0.35)
    nonisolated static let articleSleep = Color(red: 0.35, green: 0.45, blue: 0.95)
    nonisolated static let articleMindfulness = Color(red: 1.0, green: 0.58, blue: 0.0)
    nonisolated static let articleStress = Color(red: 0.42, green: 0.31, blue: 1.0)

    nonisolated static let avatarGradientStart = featuredGradientStart
    nonisolated static let avatarGradientEnd = appPrimary

    nonisolated static let destructive = stressHigh
    nonisolated static let trendNegative = stressHigh

    nonisolated static let glassBorder = Color.primary.opacity(0.12)

    nonisolated static let historyChartLine = systemBlue
    nonisolated static let historyChartGrid = Color(uiColor: UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(white: 1, alpha: 0.12)
            : UIColor(white: 0, alpha: 0.08)
    })

    nonisolated static let moodCalendarEmptyDay = Color(uiColor: UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(white: 1, alpha: 0.08)
            : UIColor(white: 0, alpha: 0.06)
    })

    // MARK: - Stress / mood (Apple system colours)

    nonisolated static func stressColor(for level: Int) -> Color {
        stressColor(for: StressCategory.from(level: level))
    }

    nonisolated static func stressColor(for category: StressCategory) -> Color {
        switch category {
        case .low: systemGreen
        case .moderate: systemOrange
        case .high: systemRed
        }
    }

    /// Four-band display color (includes purple for very high) — notifications, Watch, tinted rows.
    nonisolated static func stressDisplayColor(for level: Int) -> Color {
        let clamped = min(max(level, 0), 100)
        switch clamped {
        case 0..<34: return systemGreen
        case 34..<67: return systemOrange
        case 67..<85: return systemRed
        default: return Color.purple
        }
    }

    nonisolated static func stressBackground(for category: StressCategory, colorScheme: ColorScheme) -> Color {
        stressColor(for: category).opacity(cardTintOpacity(colorScheme: colorScheme))
    }

    nonisolated static func moodColor(for score: Int) -> Color {
        MoodColors.moodColor(for: score)
    }

    nonisolated static func moodTextColor(for score: Int) -> Color {
        MoodColors.moodTextColor(for: score)
    }

    nonisolated static func moodBackground(for score: Int, colorScheme: ColorScheme) -> Color {
        moodColor(for: score).opacity(cardTintOpacity(colorScheme: colorScheme))
    }

    nonisolated static func moodCalendarTodayHighlight(colorScheme: ColorScheme) -> Color {
        systemBlue.opacity(cardTintOpacity(colorScheme: colorScheme))
    }

    nonisolated static func checkInBackground(for category: StressCategory, colorScheme: ColorScheme) -> Color {
        stressBackground(for: category, colorScheme: colorScheme)
    }

    nonisolated static let moodSaveButtonBackground = systemBlue

    nonisolated static func articleIconColor(category: String) -> Color {
        let lower = category.lowercased()
        if lower.contains("breath") { return articleBreathing }
        if lower.contains("sleep") || lower.contains("wellness") { return articleSleep }
        if lower.contains("mind") || lower.contains("gratitude") { return articleMindfulness }
        if lower.contains("stress") || lower.contains("burnout") || lower.contains("science") {
            return articleStress
        }
        return appAccent
    }

    nonisolated static func articleIconName(category: String) -> String {
        let lower = category.lowercased()
        if lower.contains("breath") { return "lungs.fill" }
        if lower.contains("sleep") || lower.contains("wellness") { return "moon.fill" }
        if lower.contains("mind") || lower.contains("gratitude") { return "heart.fill" }
        if lower.contains("stress") || lower.contains("burnout") || lower.contains("science") {
            return "brain.head.profile"
        }
        return "brain.head.profile"
    }

    // MARK: - Private

    nonisolated private static func cardTintOpacity(colorScheme: ColorScheme) -> Double {
        colorScheme == .dark ? 0.2 : 0.12
    }
}
