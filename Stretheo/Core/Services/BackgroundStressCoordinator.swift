//
//  BackgroundStressCoordinator.swift
//  Stretheo
//
//  On-device stress measurement pipeline for HealthKit background delivery.
//  No BGTask polling — invoked only when new HRV data arrives from Apple Watch.
//

import Foundation
import OSLog

@MainActor
final class BackgroundStressCoordinator {
    static let shared = BackgroundStressCoordinator()

    private var dependencies: AppDependencies?

    private init() {}

    func configure(dependencies: AppDependencies) {
        self.dependencies = dependencies
    }

    /// Runs after HealthKit reports new HRV samples (observer + anchored query).
    @discardableResult
    func handleNewHealthData() async -> Bool {
        guard AppSettings.healthSyncEnabled else {
            StretheoLog.background.debug("skipped — Health sync disabled")
            return false
        }
        guard let dependencies else {
            StretheoLog.background.debug("skipped — dependencies not configured")
            return false
        }

        let started = Date()

        do {
            let measurement = try await dependencies.measureStressUseCase.execute(trigger: .automatic)
            await dependencies.notificationManager.scheduleStressAlertIfNeeded(
                level: measurement.stressLevel,
                category: measurement.stressCategory,
                stressRepository: dependencies.stressRepository
            )

            let elapsed = Date().timeIntervalSince(started)
            // PRIVACY FIX: stress level only at .debug (stripped in release)
            StretheoLog.background.debug(
                "saved measurement id: \(measurement.id) in \(String(format: "%.1f", elapsed))s"
            )
            return true
        } catch AppError.noHealthData {
            StretheoLog.background.debug("skipped — no health signal")
            return false
        } catch {
            StretheoLog.background.error("measurement failed — \(error.localizedDescription)")
            return false
        }
    }

    #if DEBUG
    func simulateHealthKitDataSync() async {
        StretheoLog.background.debug("simulate HealthKit HRV sync")
        _ = await handleNewHealthData()
    }
    #endif
}
