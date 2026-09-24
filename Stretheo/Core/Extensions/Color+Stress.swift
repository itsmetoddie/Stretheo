//
//  Color+Stress.swift
//  Stretheo
//

import SwiftUI

extension Color {
    static func stressColor(for level: Int) -> Color {
        AppColors.stressColor(for: level)
    }

    static func stressColor(for category: StressCategory) -> Color {
        AppColors.stressColor(for: category)
    }

    static func moodColor(for score: Int) -> Color {
        MoodColors.moodColor(for: score)
    }
}
