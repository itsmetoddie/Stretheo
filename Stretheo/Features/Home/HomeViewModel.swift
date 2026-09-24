//
//  HomeViewModel.swift
//  Stretheo
//

import Foundation
import OSLog
import SwiftUI

@MainActor
@Observable
final class HomeViewModel {
    private let dependencies: AppDependencies
    private let router: AppRouter

    let gaugeDisplay: HomeGaugeDisplayState

    var breathingTechniqueIndex: Int = 0
    var errorMessage: String?
    var showError = false

    init(dependencies: AppDependencies, router: AppRouter) {
        self.dependencies = dependencies
        self.router = router
        gaugeDisplay = HomeGaugeDisplayState(
            analysisHint: String(localized: "home.analysis.empty")
        )
    }

    func cancelPendingWork() {}

    /// Pull-to-refresh — re-reads latest measurement for gauge / hint (lists use `@Query` in `HomeView`).
    func refresh() async {
        await loadLatestMeasurement()
    }

    func dismissError() {
        showError = false
        errorMessage = nil
    }

    /// Runs HealthKit read, stress algorithm, and UI refresh. Lists update via `@Query` in `HomeView`.
    /// Returns whether a measurement completed successfully (saved or deduped).
    @discardableResult
    func measureStress() async -> Bool {
        showError = false
        errorMessage = nil

        StretheoLog.measureStress.debug("MEASURE_NOW: starting measurement")

        do {
            let measurement = try await dependencies.measureStressUseCase.execute(trigger: .manual)
            StretheoLog.measureStress.debug("MEASURE_NOW: execute returned id=\(measurement.id.uuidString, privacy: .public)")
            applyMeasurementToUI(measurement)
            HapticFeedback.success()

            Task {
                await dependencies.notificationManager.scheduleStressAlertIfNeeded(
                    level: measurement.stressLevel,
                    category: measurement.stressCategory,
                    stressRepository: dependencies.stressRepository
                )
            }
            StretheoLog.measureStress.debug("MEASURE_NOW: measureStress finished successfully")
            return true
        } catch {
            StretheoLog.measureStress.debug("MEASURE_NOW_ERROR: \(error.localizedDescription, privacy: .public)")
            presentError(error)
            HapticFeedback.warning()
            StretheoLog.measureStress.debug("MEASURE_NOW: measureStress finished with error")
            return false
        }
    }

    /// Syncs gauge from SwiftData `@Query` when measurements change.
    func syncGauge(from measurement: StressMeasurement, animated: Bool = true) {
        let hint = dependencies.stressAnalysisHintUseCase.hint(for: measurement)
        gaugeDisplay.sync(from: measurement, hint: hint, animated: animated)
    }

    /// NotificationCenter fallback when only level is available.
    func updateGaugeLevel(_ level: Int) {
        gaugeDisplay.updateLevel(level)
    }

    var activeBreathingTechnique: BreathingTechnique {
        let catalog = BreathingTechnique.all
        guard breathingTechniqueIndex >= 0, breathingTechniqueIndex < catalog.count else {
            return BreathingTechnique.fourSevenEight
        }
        return catalog[breathingTechniqueIndex]
    }

    func startBreathingSession() {
        HapticFeedback.light()
        router.openBreathing(technique: activeBreathingTechnique)
    }

    // MARK: - Private

    private func loadLatestMeasurement() async {
        do {
            if let latest = try dependencies.stressRepository.latestMeasurement() {
                applyMeasurementToUI(latest)
            } else {
                gaugeDisplay.resetEmpty(hint: String(localized: "home.analysis.empty"))
            }
        } catch {
            presentError(error)
        }
    }

    private func applyMeasurementToUI(_ measurement: StressMeasurement) {
        let hint = dependencies.stressAnalysisHintUseCase.hint(for: measurement)
        gaugeDisplay.sync(from: measurement, hint: hint)
    }

    private func presentError(_ error: Error) {
        if let appError = error as? AppError, let description = appError.errorDescription {
            errorMessage = description
        } else {
            errorMessage = error.localizedDescription
        }
        showError = true
    }
}
