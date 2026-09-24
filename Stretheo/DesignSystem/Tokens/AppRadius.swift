//
//  AppRadius.swift
//  Stretheo
//
//  Continuous corner radii — matches native iOS 26 app chrome.
//

import CoreGraphics
import SwiftUI

enum AppRadius {
    /// Full-width main cards (tab screens, modifiers).
    static let card: CGFloat = 20
    /// Nested rows and sub-panels inside cards.
    static let inner: CGFloat = 16
    /// Primary / secondary action buttons.
    static let button: CGFloat = 14
    /// Segmented pills, technique chips, period filters.
    static let pill: CGFloat = 10
    /// Tags, badges, legend swatches, icon tiles.
    static let tag: CGFloat = 8

    static func continuous(_ radius: CGFloat) -> RoundedRectangle {
        RoundedRectangle(cornerRadius: radius, style: .continuous)
    }
}
