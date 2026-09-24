//
//  MeasureStressUseCase.swift
//  Stretheo
//

import Foundation
import OSLog

struct MeasureStressUseCase {
    private let healthKit: HealthKitManager
    private let algorithm: StressAlgorithmEngine
    private let stressRepository: StressRepositoryProtocol
    private let profileRepository: UserProfileRepositoryProtocol
    private let watchConnectivity: WatchConnectivityManager

    init(
        healthKit: HealthKitManager = .shared,
        algorithm: StressAlgorithmEngine = StressAlgorithmEngine(),
        stressRepository: StressRepositoryProtocol,
        profileRepository: UserProfileRepositoryProtocol,
        watchConnectivity: WatchConnectivityManager = .shared
    ) {
        self.healthKit = healthKit
        self.algorithm = algorithm
        self.stressRepository = stressRepository
        self.profileRepository = profileRepository
        self.watchConnectivity = watchConnectivity
    }

    @MainActor
    func execute(trigger: TriggerType) async throws -> StressMeasurement {
        StretheoLog.measureStress.debug("MEASURE_NOW: execute started trigger=\(trigger.rawValue, privacy: .public)")

        if trigger == .manual, !AppSettings.hasRequestedHealthKitReadAuthorization {
            StretheoLog.measureStress.debug("MEASURE_NOW: requesting HealthKit authorization (first time this install)")
            try await healthKit.requestAuthorizationIfNeeded()
        }

        let profile = try profileRepository.fetchOrCreateProfile()
        StretheoLog.measureStress.debug("MEASURE_NOW: profile loaded")

        let input = try await healthKit.fetchHealthInput(
            birthMonth: profile.birthMonth,
            birthYear: profile.birthYear,
            sex: profile.sex
        )
        StretheoLog.measureStress.debug("MEASURE_NOW: fetched health input")

        let hasSignal = [input.hrv, input.restingHeartRate, input.currentHeartRate, input.respiratoryRate, input.sleepDuration]
            .contains { $0 != nil }
        guard hasSignal else {
            StretheoLog.measureStress.debug("MEASURE_NOW_ERROR: no health signal in input")
            throw AppError.noHealthData
        }

        let result = algorithm.compute(from: input)
        StretheoLog.measureStress.debug("MEASURE_NOW: computed stress score")

        let dedupeWindow = ServiceConstants.measurementDedupeInterval
        if let latest = try stressRepository.latestMeasurement(),
           Date().timeIntervalSince(latest.measuredAt) < dedupeWindow {
            StretheoLog.measureStress.debug(
                "MEASURE_NOW: dedupe skip — recent measurement \(Int(Date().timeIntervalSince(latest.measuredAt)), privacy: .public)s ago"
            )
            return latest
        }

        StretheoLog.measureStress.debug("MEASURE_NOW: saving measurement")
        let measurement = try await stressRepository.save(result: result, input: input, trigger: trigger)
        watchConnectivity.pushLatestStress(
            level: result.level,
            category: result.category,
            measuredAt: measurement.measuredAt,
            profile: input
        )
        NotificationCenter.default.post(
            name: .newMeasurementSaved,
            object: nil,
            userInfo: [StressNotificationUserInfoKey.level: result.level]
        )
        StretheoLog.measureStress.debug("MEASURE_NOW: saved measurement id=\(measurement.id.uuidString, privacy: .public)")
        return measurement
    }
}
