//
//  StressReferenceRanges.swift
//  StretheoShared
//

import Foundation

/// Age/sex calibrated reference ranges for normalising HealthKit metrics to 0…1 stress contribution.
struct StressReferenceRanges: Sendable, Equatable {
    let hrvLow: Double
    let hrvHigh: Double
    let restingHRBaseline: Double
    let elevatedHR: Double
    let respiratoryNormal: Double
    let respiratoryHigh: Double

    static func forProfile(age: Int, sex: ProfileSex) -> StressReferenceRanges {
        let clampedAge = min(max(age, 18), 65)
        let ageFactor = Double(clampedAge - 18) / 47.0
        let sexOffset: Double = switch sex {
        case .male: 0.0
        case .female: 5.0
        case .other: 2.5
        }
        return StressReferenceRanges(
            hrvLow: 25 + sexOffset - ageFactor * 8,
            hrvHigh: 65 + sexOffset - ageFactor * 10,
            restingHRBaseline: 58 + ageFactor * 6,
            elevatedHR: 90 + ageFactor * 8,
            respiratoryNormal: 14,
            respiratoryHigh: 20
        )
    }
}

enum StressAlgorithmWeights {
    nonisolated static let hrv: Double = 0.301
    nonisolated static let heartRate: Double = 0.236
    nonisolated static let respiratory: Double = 0.131
    nonisolated static let sleep: Double = 0.200
    nonisolated static let activityTemperature: Double = 0.131
}
