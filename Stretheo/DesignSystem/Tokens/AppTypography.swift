//
//  AppTypography.swift
//  Stretheo
//
//  Dynamic Type scale only — no hardcoded display sizes except the stress index,
//  which uses a scaled rounded variant tied to largeTitle.
//  `nonisolated` — design tokens are safe under Swift 6 default MainActor isolation.
//

import SwiftUI

enum AppTypography {
    // MARK: - Screen hierarchy

    /// Large navigation-style screen title (Figma large black headers).
    nonisolated static let screenTitle = Font.largeTitle.weight(.bold)

    /// Subtitle below screen title (grey secondary line).
    nonisolated static let screenSubtitle = Font.body

    // MARK: - Spec scale (semantic aliases)

    nonisolated static let largeTitle = Font.largeTitle
    nonisolated static let title1 = Font.title
    nonisolated static let title2 = Font.title2
    nonisolated static let title3 = Font.title3
    nonisolated static let headline = Font.headline
    nonisolated static let body = Font.body
    nonisolated static let callout = Font.callout
    nonisolated static let subheadline = Font.subheadline
    nonisolated static let footnote = Font.footnote
    nonisolated static let caption1 = Font.caption
    nonisolated static let caption2 = Font.caption2

    // MARK: - Component roles

    /// Primary stress index number (0–100) on Home / check-in rows.
    nonisolated static var stressIndex: Font {
        Font.system(.largeTitle, design: .rounded).weight(.bold)
    }

    /// Secondary large metric (recent check-in score).
    nonisolated static var stressIndexMedium: Font {
        Font.system(.title, design: .rounded).weight(.bold)
    }

    /// Card header title (e.g. "Stress Analysis").
    nonisolated static let cardTitle = Font.title3.weight(.semibold)

    /// Card header subtitle (e.g. "HealthKit integration").
    nonisolated static let cardSubtitle = Font.subheadline

    /// Section headers outside cards ("Recent Check-ins").
    nonisolated static let sectionTitle = Font.title2.weight(.bold)

    /// List row primary text.
    nonisolated static let rowPrimary = Font.headline

    /// List row secondary text.
    nonisolated static let rowSecondary = Font.subheadline

    /// Secondary card copy.
    nonisolated static let secondary = Font.callout

    /// Form labels and button-adjacent labels.
    nonisolated static let label = Font.subheadline.weight(.medium)

    /// Timestamps, metadata, axis labels.
    nonisolated static let metadata = Font.footnote

    nonisolated static let caption = Font.caption
    nonisolated static let captionBold = Font.caption.weight(.semibold)

    /// Large decorative icons (onboarding, empty states).
    nonisolated static var displayIcon: Font {
        Font.system(.largeTitle, design: .default)
    }

    /// Success / alert overlay icons on cards.
    nonisolated static var overlayIcon: Font {
        Font.system(.title, design: .default)
    }
}
