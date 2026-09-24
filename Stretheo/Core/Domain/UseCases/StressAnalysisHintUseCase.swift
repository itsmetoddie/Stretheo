//
//  StressAnalysisHintUseCase.swift
//  Stretheo
//

import Foundation

struct StressAnalysisHintUseCase {
    private let algorithm: StressAlgorithmEngine
    private let profileRepository: UserProfileRepositoryProtocol

    init(
        algorithm: StressAlgorithmEngine = StressAlgorithmEngine(),
        profileRepository: UserProfileRepositoryProtocol
    ) {
        self.algorithm = algorithm
        self.profileRepository = profileRepository
    }

    @MainActor
    func hint(for measurement: StressMeasurement) -> String {
        let category = measurement.stressCategory
        switch category {
        case .low:
            return String(localized: "home.analysis.hint.low")
        case .moderate, .high:
            return metricHint(for: measurement) ?? categoryHint(for: category)
        }
    }

    @MainActor
    private func metricHint(for measurement: StressMeasurement) -> String? {
        guard let snap = measurement.healthSnapshot else { return nil }
        let profile = try? profileRepository.fetchOrCreateProfile()
        let input = HealthInput(
            hrv: snap.hrv,
            restingHeartRate: snap.restingHeartRate,
            currentHeartRate: snap.currentHeartRate,
            respiratoryRate: snap.respiratoryRate,
            wristTemperature: snap.wristTemperature,
            activityType: snap.activityType,
            sleepDuration: snap.sleepDuration,
            sleepQualityScore: snap.sleepQualityScore,
            birthMonth: profile?.birthMonth ?? 1,
            birthYear: profile?.birthYear ?? 1990,
            sex: profile?.sex ?? .other
        )
        return algorithm.compute(from: input).breakdown.first
    }

    private func categoryHint(for category: StressCategory) -> String {
        switch category {
        case .low:
            String(localized: "home.analysis.hint.low")
        case .moderate:
            String(localized: "home.analysis.hint.moderate")
        case .high:
            String(localized: "home.analysis.hint.high")
        }
    }
}
