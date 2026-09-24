//
//  AppSpacing.swift
//  Stretheo
//
//  4pt base grid — matches Figma spacing rhythm.
//  `nonisolated` so layout constants are safe under Swift 6 default MainActor isolation.
//

import CoreGraphics

enum AppSpacing: Sendable {
    nonisolated static let xxs: CGFloat = 4
    nonisolated static let xs: CGFloat = 8
    nonisolated static let sm: CGFloat = 12
    nonisolated static let md: CGFloat = 16
    nonisolated static let lg: CGFloat = 24
    nonisolated static let xl: CGFloat = 32
    nonisolated static let xxl: CGFloat = 48

    /// Standard horizontal inset for scrollable screens (~20pt in Figma).
    nonisolated static let screenHorizontal: CGFloat = md

    /// Bottom inset so content clears the floating tab bar.
    nonisolated static let tabBarClearance: CGFloat = 100

    /// Minimum touch target per Apple HIG.
    nonisolated static let minTouchTarget: CGFloat = 44
}
