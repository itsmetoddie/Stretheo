//
//  WatchHealthManager.swift
//  StretheoWatch
//

import Combine
import Foundation
import HealthKit
import OSLog

@MainActor
final class WatchHealthManager: NSObject, ObservableObject {
    static let shared = WatchHealthManager()

    nonisolated private static let logger = Logger(
        subsystem: "com.zapreff.Stretheo",
        category: "BackgroundMonitoring"
    )

    private static weak var activeManager: WatchHealthManager?
    private static let sharedHealthStore = HKHealthStore()

    private let healthStore = WatchHealthManager.sharedHealthStore
    private let algorithm = StressAlgorithmEngine()
    private var hrvObserverQuery: HKObserverQuery?
    private var lastProcessedAt: Date?
    private var isBackgroundDeliveryRegistered = false
    /// Minimum spacing between processed measurements (HRV can arrive more often).
    private let minimumMeasurementInterval: TimeInterval = 15 * 60

    override init() {
        super.init()
        Self.activeManager = self
    }

    deinit {
        if let query = hrvObserverQuery {
            healthStore.stop(query)
        }
    }

    /// HRV observer callback (nonisolated). Always calls `completionHandler` when the handler returns.
    nonisolated private static func hrvObserverDidFire(
        completionHandler: @escaping HKObserverQueryCompletionHandler,
        error: Error?
    ) {
        Self.logger.info("HRV observer fired at \(Date(), privacy: .public)")

        if let error {
            Self.logger.error("HRV observer error: \(error.localizedDescription, privacy: .public)")
            Self.logger.info("Calling completionHandler")
            completionHandler()
            Self.logger.info("completionHandler called successfully")
            return
        }

        // NOTE: Firing frequency here is controlled by watchOS/HealthKit based on the wearer's
        // physiological state, not by app logic. Infrequent firing during rest/low-activity
        // periods is expected platform behavior, not a defect. See project documentation:
        // "Remaining design factors" — HRV sample rate limitation.
        HRVDiagnosticStore.recordWatchObserverFire()
        Self.logger.debug("HRV_OBSERVER_FIRED: new sample delivered by HealthKit at \(Date(), privacy: .public)")

        // Acknowledge delivery immediately — never block this HealthKit thread on async work.
        Self.logger.info("Calling completionHandler")
        completionHandler()
        Self.logger.info("completionHandler called successfully")

        Task { @MainActor in
            await activeManager?.performMeasurementIfNeeded()
        }
    }

    nonisolated private static func authorizationDidComplete(success: Bool, error: Error?) {
        if let error {
            Self.logger.error("Authorization error: \(error.localizedDescription, privacy: .public)")
        }
        guard success else { return }
        Task { @MainActor in
            activeManager?.setupObserverQueries()
        }
    }

    /// On-demand reading using the existing HRV processing path (same as background delivery).
    func measureNow() async {
        await performMeasurementIfNeeded()
    }

    /// Background refresh fallback and HRV observer path — reads latest HealthKit samples and syncs stress.
    func performMeasurementIfNeeded() async {
        let lastMeasuredAt = lastProcessedAt
        let elapsed = Date().timeIntervalSince(lastMeasuredAt ?? .distantPast)

        guard elapsed >= minimumMeasurementInterval else {
            Self.logger.debug(
                "MEASUREMENT_SKIPPED_APP_THROTTLE: HRV sample was available but minimumMeasurementInterval (\(Int(self.minimumMeasurementInterval), privacy: .public)s) not yet elapsed (\(Int(elapsed), privacy: .public)s since last). This is the 15-minute app-level cap, not a platform limitation."
            )
            return
        }

        Self.logger.debug("MEASUREMENT_PROCEEDING: HRV sample available and interval elapsed, computing stress result")
        await handleNewHRVData()
    }

    /// Opportunistic quiet-period diagnostic — call on any Watch wake, not a new background task.
    func logHRVObserverQuietPeriodIfNeeded() {
        guard let lastObserverFire = HRVDiagnosticStore.watchLastObserverFire(),
              Date().timeIntervalSince(lastObserverFire) > HRVDiagnosticStore.quietPeriodThreshold else {
            return
        }
        Self.logger.debug(
            "HRV_OBSERVER_QUIET_PERIOD: no new HRV sample delivered by HealthKit in over 4 hours. Expected during low activity/rest; only investigate further if this persists across active periods too."
        )
    }

    // AUDIT: observer is intentionally re-registered on foreground so watchOS can recover delivery after suspension.
    func enableBackgroundMonitoring(callSite: String) {
        Self.logger.info("Re-registering HRV observer from \(callSite, privacy: .public)")

        guard HKHealthStore.isHealthDataAvailable() else {
            Self.logger.error("HealthKit unavailable")
            return
        }

        let hrvType = HKQuantityType(.heartRateVariabilitySDNN)

        let types: Set<HKSampleType> = [
            hrvType,
            HKQuantityType(.heartRate)
        ]

        healthStore.requestAuthorization(toShare: [], read: types) { success, error in
            Self.authorizationDidComplete(success: success, error: error)
        }
    }

    private func setupObserverQueries() {
        let hrvType = HKQuantityType(.heartRateVariabilitySDNN)

        if !isBackgroundDeliveryRegistered {
            // Primary pipeline: immediate background delivery when Apple Watch records new HRV.
            healthStore.enableBackgroundDelivery(for: hrvType, frequency: .immediate) { success, error in
                if let error {
                    Self.logger.error("enableBackgroundDelivery failed: \(error.localizedDescription, privacy: .public)")
                } else if success {
                    Self.logger.info("enableBackgroundDelivery registered")
                } else {
                    Self.logger.error("enableBackgroundDelivery returned success=false without error")
                }
                if success {
                    Task { @MainActor in
                        WatchHealthManager.shared.isBackgroundDeliveryRegistered = true
                    }
                }
            }
        }

        if let existing = hrvObserverQuery {
            healthStore.stop(existing)
            hrvObserverQuery = nil
            Self.logger.debug("Stopped prior HRV observer before re-registering")
        }

        let query = HKObserverQuery(sampleType: hrvType, predicate: nil) { _, completionHandler, error in
            Self.hrvObserverDidFire(completionHandler: completionHandler, error: error)
        }

        hrvObserverQuery = query
        healthStore.execute(query)
        Self.logger.info("HRV observer query registered")
    }

    private func handleNewHRVData() async {
        if let last = lastProcessedAt {
            let elapsed = Date().timeIntervalSince(last)
            if elapsed < minimumMeasurementInterval {
                Self.logger.info(
                    "Measurement skipped — \(Int(elapsed), privacy: .public)s since last (minimum \(Int(self.minimumMeasurementInterval), privacy: .public)s)"
                )
                return
            }
        }

        Self.logger.info("performMeasurementIfNeeded — reading HealthKit and computing stress")
        let snapshot = await readWatchHealthSnapshot()
        let profiled = WatchProfileStore.profileFields(for: snapshot)

        // Mirror MeasureStressUseCase: skip fabricate-from-empty-input (level 50 / moderate).
        let hasSignal = [
            profiled.hrv,
            profiled.restingHeartRate,
            profiled.currentHeartRate,
            profiled.respiratoryRate,
            profiled.sleepDuration
        ].contains { $0 != nil }
        guard hasSignal else {
            Self.logger.info("Measurement skipped — no health signal in snapshot")
            return
        }

        let result = algorithm.compute(from: profiled)
        Self.logger.debug("Computed stress result")

        let measuredAt = Date()
        WatchStressReadingHistory.append(level: result.level, measuredAt: measuredAt)

        let watchNotificationSent = await WatchNotificationManager.shared.scheduleIfNeeded(
            result: result,
            measuredAt: measuredAt
        )

        Self.logger.debug("WatchConnectivity send attempted")
        WatchConnectivityManager.shared.sendStressResult(
            result,
            measuredAt: measuredAt,
            input: profiled,
            watchNotificationSent: watchNotificationSent
        )

        do {
            try AppDependencies.shared.stressRepository.save(
                result: result,
                input: profiled,
                trigger: .automaticWatch
            )
        } catch {
            Self.logger.error("Local save failed: \(error.localizedDescription, privacy: .public)")
        }

        lastProcessedAt = measuredAt
        Self.logger.info("Measurement saved locally at \(measuredAt.formatted(), privacy: .public)")
    }

    func readWatchHealthSnapshot() async -> HealthInput {
        async let hrv = readLatestHRV()
        async let heartRate = readLatestHeartRate()
        async let wristTemp = readLatestWristTemp()

        let (hrvVal, hrVal, tempVal) = await (hrv, heartRate, wristTemp)

        return HealthInput(
            hrv: hrvVal,
            restingHeartRate: nil,
            currentHeartRate: hrVal,
            respiratoryRate: nil,
            wristTemperature: tempVal,
            activityType: nil,
            sleepDuration: nil,
            sleepQualityScore: nil,
            birthMonth: 1,
            birthYear: 1990,
            sex: .other
        )
    }

    private func readLatestHRV() async -> Double? {
        await readLatestQuantity(
            .heartRateVariabilitySDNN,
            unit: .secondUnit(with: .milli)
        )
    }

    private func readLatestHeartRate() async -> Double? {
        await readLatestQuantity(
            .heartRate,
            unit: HKUnit.count().unitDivided(by: .minute())
        )
    }

    private func readLatestWristTemp() async -> Double? {
        if #available(watchOS 9.0, *) {
            return await readLatestQuantity(
                .appleSleepingWristTemperature,
                unit: .degreeCelsius()
            )
        }
        return nil
    }

    private func readLatestQuantity(
        _ identifier: HKQuantityTypeIdentifier,
        unit: HKUnit
    ) async -> Double? {
        guard let type = HKQuantityType.quantityType(forIdentifier: identifier) else { return nil }

        let now = Date()
        let lookbackStart = Calendar.current.date(byAdding: .hour, value: -24, to: now)
            ?? now.addingTimeInterval(-86400)

        let sample: HKQuantitySample? = await withCheckedContinuation { continuation in
            let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
            let query = HKSampleQuery(
                sampleType: type,
                predicate: nil,
                limit: 1,
                sortDescriptors: [sort]
            ) { _, samples, _ in
                continuation.resume(returning: samples?.first as? HKQuantitySample)
            }
            healthStore.execute(query)
        }

        guard let sample, sample.endDate >= lookbackStart else { return nil }
        return sample.quantity.doubleValue(for: unit)
    }
}
