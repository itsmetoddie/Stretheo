//
//  HomeGaugeDisplayState.swift
//  Stretheo
//
//  Gauge-only display state so Home stress UI updates do not invalidate the full Home screen.
//

import Foundation
import SwiftUI

@MainActor
@Observable
final class HomeGaugeDisplayState {
    var currentStressLevel: Int?
    var currentCategory: StressCategory = .low
    var analysisHint: String = ""
    var lastMeasuredAt: Date?
    var stressGaugeAnimationToken = 0

    var hasStressMeasurement: Bool { currentStressLevel != nil }
    var displayStressLevel: Int { currentStressLevel ?? 0 }

    init(analysisHint: String = "") {
        self.analysisHint = analysisHint
    }

    func sync(from measurement: StressMeasurement, hint: String, animated: Bool = true) {
        if animated {
            applyMeasurementToUI(measurement, hint: hint)
        } else {
            applyMeasurementToUIInstantly(measurement, hint: hint)
        }
    }

    func updateLevel(_ level: Int) {
        let springResponse = CalmAnimationTiming.reduceMotion ? 0 : 0.8
        withAnimation(.spring(response: springResponse, dampingFraction: 0.85)) {
            currentStressLevel = level
            currentCategory = StressCategory.from(level: level)
            stressGaugeAnimationToken += 1
        }
    }

    func resetEmpty(hint: String) {
        currentStressLevel = nil
        analysisHint = hint
    }

    private func applyMeasurementToUI(_ measurement: StressMeasurement, hint: String) {
        let springResponse = CalmAnimationTiming.reduceMotion ? 0 : 0.8
        withAnimation(.spring(response: springResponse, dampingFraction: 0.85)) {
            applyMeasurementValues(from: measurement, hint: hint)
            stressGaugeAnimationToken += 1
        }
    }

    private func applyMeasurementToUIInstantly(_ measurement: StressMeasurement, hint: String) {
        applyMeasurementValues(from: measurement, hint: hint)
    }

    private func applyMeasurementValues(from measurement: StressMeasurement, hint: String) {
        currentStressLevel = measurement.stressLevel
        currentCategory = measurement.stressCategory
        lastMeasuredAt = measurement.measuredAt
        analysisHint = hint
    }
}
