//
//  WatchPalette.swift
//  StretheoWatch
//
//  Shared watch palette for stress UI and complications.
//

import SwiftUI

enum WatchPalette {
    static let primary = Color(red: 0, green: 0.48, blue: 1)
    static let low = Color(red: 0.20, green: 0.78, blue: 0.35)
    static let moderate = Color(red: 1, green: 0.58, blue: 0)
    static let high = Color(red: 1, green: 0.23, blue: 0.19)

    static func color(for category: String) -> Color {
        switch category {
        case "low": low
        case "moderate": moderate
        case "high": high
        default: moderate
        }
    }

    static func displayColor(for level: Int) -> Color {
        let clamped = min(max(level, 0), 100)
        switch clamped {
        case 0..<34: return low
        case 34..<67: return moderate
        case 67..<85: return high
        default: return Color.purple
        }
    }

    static func categoryTitle(_ category: String) -> String {
        switch category {
        case "low": "Low"
        case "moderate": "Moderate"
        case "high": "High"
        default: category.capitalized
        }
    }
}
