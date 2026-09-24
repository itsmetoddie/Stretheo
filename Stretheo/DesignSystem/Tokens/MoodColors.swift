//
//  MoodColors.swift
//  Stretheo
//
//  Canonical mood score palette — use everywhere for scores 1–5.
//

import SwiftUI

enum MoodColors {
    nonisolated static func moodColor(for score: Int) -> Color {
        switch score {
        case 1: .red
        case 2: .orange
        case 3: .yellow
        case 4: .green
        case 5: .mint
        default: Color(.systemGray)
        }
    }

    /// Text/icon color on light mood tint fills — deepens yellow for WCAG AA contrast.
    nonisolated static func moodTextColor(for score: Int) -> Color {
        switch score {
        case 3: Color(red: 0.72, green: 0.55, blue: 0.0)
        default: moodColor(for: score)
        }
    }
}
