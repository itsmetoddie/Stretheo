//
//  HealthKitManager.swift
//  Stretheo
//
//  HealthKit access. HKHealthStore is thread-safe for concurrent queries — not an actor,
//  so parallel async let actually runs queries simultaneously.
//
//  Note: SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor applies to this type; HealthKit query
//  bridge methods are explicitly nonisolated so completion handlers can resume continuations
//  from HealthKit's background queues without main-actor hops.
//  Read authorization: Apple always reports `.notDetermined` for read types even after grant.
//  Request authorization, then run queries; nil results mean missing data, not denial.
//

import Foundation
import HealthKit
import OSLog

private struct SleepMetrics: Sendable {
    let duration: Double?
    let quality: Int?
}

private enum HealthKitQueryTiming {
    nonisolated static let timeoutSeconds: TimeInterval = 8
}

/// Builds validated date-range predicates from a single `now` snapshot so start/end cannot drift apart.
private enum HealthKitQueryPredicate {
    /// Shared lookback predicate — single source of truth for all date-bounded queries.
    nonisolated static func recentDateRange(hours: Int, now: Date = Date(), queryName: String) -> NSPredicate {
        let start = Calendar.current.date(byAdding: .hour, value: -hours, to: now)
            ?? now.addingTimeInterval(-Double(hours) * 3600)
        return samples(from: start, to: now, queryName: queryName)
    }

    nonisolated static func fromStartOfDay(now: Date = Date(), queryName: String) -> NSPredicate {
        let start = Calendar.current.startOfDay(for: now)
        return samples(from: start, to: now, queryName: queryName)
    }

    nonisolated static func samples(from start: Date, to end: Date, queryName: String) -> NSPredicate {
        let validStart = start < end ? start : end.addingTimeInterval(-3600)
        StretheoLog.healthKit.debug(
            "HK predicate \(queryName): \(validStart) to \(end) — valid: \(validStart < end)"
        )
        return HKQuery.predicateForSamples(withStart: validStart, end: end, options: .strictStartDate)
    }
}

/// Runs HealthKit queries on the main actor with TaskGroup timeout — matches the isolation-test
/// pattern that receives callbacks on device (MainActor execute + outer timeout race).
private enum HealthKitQueryRunner {
    nonisolated static func run<T: Sendable>(
        queryName: String,
        timeoutSeconds: TimeInterval = HealthKitQueryTiming.timeoutSeconds,
        defaultValue: T,
        work: @MainActor @escaping () async -> T
    ) async -> T {
        await withTaskGroup(of: T.self) { group in
            group.addTask {
                await work()
            }
            group.addTask {
                try? await Task.sleep(for: .seconds(timeoutSeconds))
                StretheoLog.healthKit.debug(
                    "HK_QUERY_TIMEOUT: \(queryName) after \(Int(timeoutSeconds))s"
                )
                return defaultValue
            }
            let result = await group.next() ?? defaultValue
            group.cancelAll()
            return result
        }
    }
}

final class HealthKitManager: @unchecked Sendable {
    static let shared = HealthKitManager()

    /// Single process-wide store — same instance for authorization and all queries.
    nonisolated private static var healthStore: HKHealthStore {
        HealthKitStoreProvider.shared
    }

    private let calendar = Calendar.current
    private let observerLock = NSLock()
    private var hrvObserverQuery: HKQuery?
    private var backgroundMeasureHandler: (@Sendable () async -> Void)?
    private var lastObserverTrigger: Date?
    private let observerMinimumInterval: TimeInterval = ServiceConstants.backgroundMeasurementMinimumInterval

    // MARK: - Required read types (per product spec)

    static let readTypes: Set<HKObjectType> = {
        var types = Set<HKObjectType>()
        insertQuantity(.heartRateVariabilitySDNN, into: &types)
        insertQuantity(.restingHeartRate, into: &types)
        insertQuantity(.heartRate, into: &types)
        insertQuantity(.respiratoryRate, into: &types)
        insertQuantity(.appleSleepingWristTemperature, into: &types)
        insertQuantity(.activeEnergyBurned, into: &types)
        insertQuantity(.stepCount, into: &types)
        if let sleep = HKCategoryType.categoryType(forIdentifier: .sleepAnalysis) {
            types.insert(sleep)
        }
        types.insert(HKObjectType.workoutType())
        return types
    }()

    static let writeTypes: Set<HKSampleType> = []

    var isAvailable: Bool {
        HKHealthStore.isHealthDataAvailable()
    }

    // MARK: - Authorization

    func primaryAuthorizationStatus() -> HKAuthorizationStatus {
        authorizationStatus(for: .heartRate)
    }

    func authorizationStatus(for identifier: HKQuantityTypeIdentifier) -> HKAuthorizationStatus {
        guard let type = HKQuantityType.quantityType(forIdentifier: identifier) else {
            return .notDetermined
        }
        return Self.healthStore.authorizationStatus(for: type)
    }

    /// Preference flag after the Health permission sheet — best-effort given Apple's read-privacy rules.
    ///
    /// `authorizationStatus(for:)` only reflects **share/write** permission. This app is read-only
    /// (`writeTypes` is empty), so status typically stays `.notDetermined` after grant or deny.
    /// When that happens, a completed request (`hasRequestedHealthKitReadAuthorization`) is the
    /// only signal that the sheet finished without a hard failure / unavailable store.
    func healthSyncPreferenceAfterAuthorizationPrompt() -> Bool {
        guard isAvailable else { return false }
        switch primaryAuthorizationStatus() {
        case .sharingAuthorized:
            return true
        case .sharingDenied:
            return false
        case .notDetermined:
            return AppSettings.hasRequestedHealthKitReadAuthorization
        @unknown default:
            return AppSettings.hasRequestedHealthKitReadAuthorization
        }
    }

    /// Requests HealthKit read access once per install. Safe to call from multiple code paths — coalesced.
    func requestAuthorizationIfNeeded() async throws {
        guard !AppSettings.hasRequestedHealthKitReadAuthorization else {
            StretheoLog.healthKit.debug("requestAuthorization skipped — already requested this install")
            return
        }
        try await requestAuthorization()
    }

    func requestAuthorization() async throws {
        guard isAvailable else { throw AppError.healthKitUnavailable }
        StretheoLog.healthKit.debug("requestAuthorization — presenting HealthKit permission sheet")
        try await Self.healthStore.requestAuthorization(toShare: Self.writeTypes, read: Self.readTypes)
        AppSettings.hasRequestedHealthKitReadAuthorization = true
        StretheoLog.healthKit.debug(
            "requestAuthorization completed (read status remains notDetermined by design — proceed with queries; nil means no data or denied)"
        )
    }

    // MARK: - Smart background monitoring (HRV observer — no BGTask polling)

    /// HealthKit wakes the app when Apple Watch syncs new HRV; handler runs on-device measurement only.
    func enableSmartBackgroundMonitoring(onNewData: @escaping @Sendable () async -> Void) async {
        backgroundMeasureHandler = onNewData
        guard isAvailable else { return }

        // CLEANED: avoid re-registering observer queries on every bootstrap when already active
        if hrvObserverQuery != nil, AppSettings.healthKitBackgroundDeliveryEnabled {
            StretheoLog.healthKit.debug("Smart background monitoring already active — skipping re-registration")
            return
        }

        do {
            try await requestAuthorizationIfNeeded()
            stopBackgroundObservers()
            try await enableHRVBackgroundDelivery()
            await primeHRVQueryAnchorIfNeeded()
            startHRVObserver()
            StretheoLog.healthKit.info("Smart background monitoring enabled (HRV observer, hourly delivery)")
        } catch {
            StretheoLog.healthKit.error("Smart background monitoring failed: \(error.localizedDescription)")
        }
    }

    func stopBackgroundDelivery() {
        stopBackgroundObservers()
        backgroundMeasureHandler = nil
        guard AppSettings.healthKitBackgroundDeliveryEnabled,
              let hrvType = HKQuantityType.quantityType(forIdentifier: .heartRateVariabilitySDNN) else {
            StretheoLog.healthKit.debug("Background monitoring stopped")
            return
        }
        Self.healthStore.disableBackgroundDelivery(for: hrvType) { _, _ in }
        AppSettings.healthKitBackgroundDeliveryEnabled = false
        StretheoLog.healthKit.debug("Background monitoring stopped; delivery disabled")
    }

    private func enableHRVBackgroundDelivery() async throws {
        guard !AppSettings.healthKitBackgroundDeliveryEnabled else { return }
        guard let hrvType = HKQuantityType.quantityType(forIdentifier: .heartRateVariabilitySDNN) else {
            throw AppError.healthKitReadFailed(HKQuantityTypeIdentifier.heartRateVariabilitySDNN.rawValue)
        }
        try await enableBackgroundDelivery(for: hrvType, frequency: .hourly)
        AppSettings.healthKitBackgroundDeliveryEnabled = true
    }

    private func enableBackgroundDelivery(
        for sampleType: HKSampleType,
        frequency: HKUpdateFrequency
    ) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            Self.healthStore.enableBackgroundDelivery(for: sampleType, frequency: frequency) { success, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if success {
                    continuation.resume()
                } else {
                    continuation.resume(throwing: AppError.healthKitReadFailed(sampleType.identifier))
                }
            }
        }
    }

    private func startHRVObserver() {
        guard let hrvType = HKQuantityType.quantityType(forIdentifier: .heartRateVariabilitySDNN) else { return }

        let query = HKObserverQuery(sampleType: hrvType, predicate: nil) { [weak self] _, completionHandler, error in
            if let error {
                StretheoLog.healthKit.error("HRV observer error: \(error.localizedDescription)")
                completionHandler()
                return
            }
            guard let self else {
                completionHandler()
                return
            }
            HRVDiagnosticStore.recordIPhoneObserverFire()
            StretheoLog.healthKit.debug(
                "IPHONE_HRV_OBSERVER_FIRED: backup observer received sample at \(Date())"
            )
            // Acknowledge delivery immediately — never block this HealthKit thread on async work.
            completionHandler()
            Task { [weak self] in
                await self?.handleNewHealthDataFromObserver()
            }
        }

        observerLock.lock()
        hrvObserverQuery = query
        observerLock.unlock()
        Self.healthStore.execute(query)
    }

    private func stopBackgroundObservers() {
        observerLock.lock()
        let query = hrvObserverQuery
        hrvObserverQuery = nil
        observerLock.unlock()
        if let query {
            Self.healthStore.stop(query)
        }
    }

    private func handleNewHealthDataFromObserver() async {
        let elapsed = secondsSinceLastObserverTrigger()

        guard shouldFireBackgroundMeasure() else {
            StretheoLog.healthKit.debug(
                "IPHONE_MEASUREMENT_SKIPPED_APP_THROTTLE: HRV sample was available but minimumMeasurementInterval (\(Int(self.observerMinimumInterval))s) not yet elapsed (\(Int(elapsed))s since last). This is the 45-minute app-level cap, not a platform limitation."
            )
            return
        }

        let hasNewSamples = await ingestNewHRVSamples()
        guard hasNewSamples else {
            StretheoLog.healthKit.debug("HRV observer: no new samples since anchor")
            return
        }

        StretheoLog.healthKit.debug(
            "IPHONE_MEASUREMENT_PROCEEDING: HRV sample available and interval elapsed, running on-device stress pipeline"
        )
        guard let handler = backgroundMeasureHandler else { return }
        await handler()
    }

    private func shouldFireBackgroundMeasure() -> Bool {
        observerLock.lock()
        defer { observerLock.unlock() }
        let now = Date()
        if let last = lastObserverTrigger,
           now.timeIntervalSince(last) < observerMinimumInterval {
            return false
        }
        lastObserverTrigger = now
        return true
    }

    private func secondsSinceLastObserverTrigger() -> TimeInterval {
        observerLock.lock()
        defer { observerLock.unlock() }
        return Date().timeIntervalSince(lastObserverTrigger ?? .distantPast)
    }

    // MARK: - HRV anchored queries (new samples only)

    private func primeHRVQueryAnchorIfNeeded() async {
        guard loadHRVQueryAnchor() == nil else { return }
        guard let hrvType = HKQuantityType.quantityType(forIdentifier: .heartRateVariabilitySDNN) else { return }

        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            let query = HKAnchoredObjectQuery(
                type: hrvType,
                predicate: nil,
                anchor: nil,
                limit: 0
            ) { [weak self] _, _, _, newAnchor, error in
                if let error {
                    StretheoLog.healthKit.error("HRV anchor prime failed: \(error.localizedDescription)")
                } else if let newAnchor {
                    self?.saveHRVQueryAnchor(newAnchor)
                    StretheoLog.healthKit.debug("HRV anchor primed (no historical replay)")
                }
                continuation.resume()
            }
            Self.healthStore.execute(query)
        }
    }

    private func ingestNewHRVSamples() async -> Bool {
        guard let hrvType = HKQuantityType.quantityType(forIdentifier: .heartRateVariabilitySDNN) else {
            return false
        }

        return await withCheckedContinuation { continuation in
            let query = HKAnchoredObjectQuery(
                type: hrvType,
                predicate: nil,
                anchor: loadHRVQueryAnchor(),
                limit: HKObjectQueryNoLimit
            ) { [weak self] _, samples, _, newAnchor, error in
                if let error {
                    StretheoLog.healthKit.error("HRV anchored query error: \(error.localizedDescription)")
                    continuation.resume(returning: false)
                    return
                }

                if let newAnchor {
                    self?.saveHRVQueryAnchor(newAnchor)
                }

                let newSamples = (samples as? [HKQuantitySample]) ?? []
                continuation.resume(returning: !newSamples.isEmpty)
            }
            Self.healthStore.execute(query)
        }
    }

    nonisolated private func loadHRVQueryAnchor() -> HKQueryAnchor? {
        HRVQueryAnchorStorage.load()
    }

    nonisolated private func saveHRVQueryAnchor(_ anchor: HKQueryAnchor) {
        HRVQueryAnchorStorage.save(anchor)
    }

    // MARK: - Snapshot for algorithm

    /// Orchestrates parallel HealthKit reads. Nonisolated so query continuations are not tied to the main actor.
    /// Does not call `requestAuthorization` — that runs once at onboarding/launch, not per measurement.
    nonisolated func fetchHealthInput(
        birthMonth: Int,
        birthYear: Int,
        sex: ProfileSex
    ) async throws -> HealthInput {
        guard HKHealthStore.isHealthDataAvailable() else { throw AppError.healthKitUnavailable }

        let now = Date()
        StretheoLog.healthKit.debug("fetchHealthInput — starting parallel queries at \(now)")
        let queryStart = Date()

        async let hrvResult = queryHRV()
        async let heartRateResult = queryHeartRate()
        async let restingHeartRateResult = queryRestingHeartRate()
        async let respiratoryRateResult = queryRespiratoryRate()
        async let sleepResult = querySleep()
        async let wristTempResult = queryWristTemperature()
        async let workoutResult = queryRecentWorkout()
        async let stepsResult = queryStepCount()
        async let energyResult = queryActiveEnergy()

        let (
            hrvValue,
            heartRateValue,
            restingHeartRateValue,
            respiratoryRateValue,
            sleepMetrics,
            wristTempValue,
            hasWorkout,
            stepCount,
            activeEnergy
        ) = await (
            hrvResult,
            heartRateResult,
            restingHeartRateResult,
            respiratoryRateResult,
            sleepResult,
            wristTempResult,
            workoutResult,
            stepsResult,
            energyResult
        )

        let activityResult = Self.deriveActivityType(
            hasWorkout: hasWorkout,
            steps: stepCount,
            activeEnergy: activeEnergy
        )

        let elapsed = Date().timeIntervalSince(queryStart)
        StretheoLog.healthKit.debug("fetchHealthInput finished in \(String(format: "%.2f", elapsed))s")

        let input = HealthInput(
            hrv: hrvValue,
            restingHeartRate: restingHeartRateValue,
            currentHeartRate: heartRateValue,
            respiratoryRate: respiratoryRateValue,
            wristTemperature: wristTempValue,
            activityType: activityResult,
            sleepDuration: sleepMetrics.duration,
            sleepQualityScore: sleepMetrics.quality,
            birthMonth: birthMonth,
            birthYear: birthYear,
            sex: sex
        )

        let signalCount = [
            input.hrv as Any?,
            input.restingHeartRate as Any?,
            input.currentHeartRate as Any?,
            input.respiratoryRate as Any?,
            input.wristTemperature as Any?,
            input.sleepDuration as Any?,
            input.activityType as Any?
        ].compactMap { $0 }.count
        StretheoLog.healthKit.debug(
            "snapshot assembled — \(signalCount) of 7 health signals present"
        )

        return input
    }

    // MARK: - Parallel metric queries

    nonisolated private static func deriveActivityType(
        hasWorkout: Bool,
        steps: Double?,
        activeEnergy: Double?
    ) -> String? {
        if hasWorkout { return "active" }

        let stepCount = steps ?? 0
        let kcal = activeEnergy ?? 0
        if stepCount >= 6_000 || kcal >= 350 { return "active" }
        if stepCount > 0 || kcal > 0 { return "rest" }
        return "rest"
    }

    nonisolated private func queryHRV() async -> Double? {
        await mostRecentQuantity(
            .heartRateVariabilitySDNN,
            unit: .secondUnit(with: .milli),
            lookbackHours: 24,
            queryName: "HeartRateVariabilitySDNN"
        )
    }

    nonisolated private func queryHeartRate() async -> Double? {
        await mostRecentQuantity(
            .heartRate,
            unit: HKUnit.count().unitDivided(by: .minute()),
            lookbackHours: 1,
            queryName: "HeartRate"
        )
    }

    nonisolated private func queryRestingHeartRate() async -> Double? {
        await mostRecentQuantity(
            .restingHeartRate,
            unit: HKUnit.count().unitDivided(by: .minute()),
            lookbackHours: 24,
            queryName: "RestingHeartRate"
        )
    }

    nonisolated private func queryRespiratoryRate() async -> Double? {
        await mostRecentQuantity(
            .respiratoryRate,
            unit: HKUnit.count().unitDivided(by: .minute()),
            lookbackHours: 24,
            queryName: "RespiratoryRate"
        )
    }

    nonisolated private func queryWristTemperature() async -> Double? {
        guard HKHealthStore.isHealthDataAvailable(),
              HKQuantityType.quantityType(forIdentifier: .appleSleepingWristTemperature) != nil else {
            StretheoLog.healthKit.debug("HK_QUERY_SKIP: AppleSleepingWristTemperature — unavailable on device")
            return nil
        }

        return await mostRecentQuantity(
            .appleSleepingWristTemperature,
            unit: .degreeCelsius(),
            lookbackHours: 24,
            queryName: "AppleSleepingWristTemperature"
        )
    }

    nonisolated private func querySleep() async -> SleepMetrics {
        await sleepSummary(lookbackHours: 8, queryName: "SleepAnalysis")
    }

    nonisolated private func queryRecentWorkout() async -> Bool {
        guard HKHealthStore.isHealthDataAvailable() else {
            StretheoLog.healthKit.debug("HK_QUERY_SKIP: HKWorkoutTypeIdentifier — HealthKit unavailable")
            return false
        }

        return await hasRecentWorkout(queryName: "HKWorkoutTypeIdentifier")
    }

    nonisolated private func queryStepCount() async -> Double? {
        await cumulativeQuantity(
            .stepCount,
            unit: .count(),
            queryName: "StepCount"
        )
    }

    nonisolated private func queryActiveEnergy() async -> Double? {
        await cumulativeQuantity(
            .activeEnergyBurned,
            unit: .kilocalorie(),
            queryName: "ActiveEnergyBurned"
        )
    }

    // MARK: - Low-level queries

    nonisolated private func mostRecentQuantity(
        _ identifier: HKQuantityTypeIdentifier,
        unit: HKUnit,
        lookbackHours: Int,
        queryName: String
    ) async -> Double? {
        guard let type = HKQuantityType.quantityType(forIdentifier: identifier) else {
            StretheoLog.healthKit.debug("HK_QUERY_SKIP: \(queryName) — quantity type unavailable")
            return nil
        }

        return await HealthKitQueryRunner.run(
            queryName: queryName,
            defaultValue: nil as Double?
        ) {
            StretheoLog.healthKit.debug("HK_QUERY_START: \(queryName)")
            let now = Date()
            let predicate = HealthKitQueryPredicate.recentDateRange(
                hours: lookbackHours,
                now: now,
                queryName: queryName
            )
            return await withCheckedContinuation { (continuation: CheckedContinuation<Double?, Never>) in
                let query = HKSampleQuery(
                    sampleType: type,
                    predicate: predicate,
                    limit: 1,
                    sortDescriptors: [
                        NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
                    ]
                ) { _, samples, error in
                    StretheoLog.healthKit.debug("HK_QUERY_CALLBACK_FIRED: \(queryName)")
                    if let error {
                        StretheoLog.healthKit.debug("HK_QUERY_ERROR: \(queryName) - \(error.localizedDescription)")
                        continuation.resume(returning: nil)
                        return
                    }
                    let count = samples?.count ?? 0
                    StretheoLog.healthKit.debug("HK_QUERY_COMPLETE: \(queryName) - \(count) samples")
                    guard let sample = samples?.first as? HKQuantitySample else {
                        continuation.resume(returning: nil)
                        return
                    }
                    continuation.resume(returning: sample.quantity.doubleValue(for: unit))
                }
                StretheoLog.healthKit.debug("HK_QUERY_EXECUTING: \(queryName) — calling healthStore.execute()")
                Self.healthStore.execute(query)
            }
        }
    }

    nonisolated private func cumulativeQuantity(
        _ identifier: HKQuantityTypeIdentifier,
        unit: HKUnit,
        queryName: String
    ) async -> Double? {
        guard let type = HKQuantityType.quantityType(forIdentifier: identifier) else {
            StretheoLog.healthKit.debug("HK_QUERY_SKIP: \(queryName) — quantity type unavailable")
            return nil
        }

        return await HealthKitQueryRunner.run(
            queryName: queryName,
            defaultValue: nil as Double?
        ) {
            StretheoLog.healthKit.debug("HK_QUERY_START: \(queryName)")
            let now = Date()
            let predicate = HealthKitQueryPredicate.fromStartOfDay(now: now, queryName: queryName)
            return await withCheckedContinuation { (continuation: CheckedContinuation<Double?, Never>) in
                let query = HKStatisticsQuery(
                    quantityType: type,
                    quantitySamplePredicate: predicate,
                    options: .cumulativeSum
                ) { _, statistics, error in
                    StretheoLog.healthKit.debug("HK_QUERY_CALLBACK_FIRED: \(queryName)")
                    if let error {
                        StretheoLog.healthKit.debug("HK_QUERY_ERROR: \(queryName) - \(error.localizedDescription)")
                        continuation.resume(returning: nil)
                        return
                    }
                    let value = statistics?.sumQuantity()?.doubleValue(for: unit)
                    StretheoLog.healthKit.debug(
                        "HK_QUERY_COMPLETE: \(queryName) - \(value != nil ? "sum available" : "0 samples")"
                    )
                    continuation.resume(returning: value)
                }
                StretheoLog.healthKit.debug("HK_QUERY_EXECUTING: \(queryName) — calling healthStore.execute()")
                Self.healthStore.execute(query)
            }
        }
    }

    nonisolated private func sleepSummary(lookbackHours: Int, queryName: String) async -> SleepMetrics {
        guard let sleepType = HKCategoryType.categoryType(forIdentifier: .sleepAnalysis) else {
            StretheoLog.healthKit.debug("HK_QUERY_SKIP: \(queryName) — sleep type unavailable")
            return SleepMetrics(duration: nil, quality: nil)
        }

        let samples: [HKCategorySample] = await HealthKitQueryRunner.run(
            queryName: queryName,
            defaultValue: [] as [HKCategorySample]
        ) {
            StretheoLog.healthKit.debug("HK_QUERY_START: \(queryName)")
            let now = Date()
            let predicate = HealthKitQueryPredicate.recentDateRange(
                hours: lookbackHours,
                now: now,
                queryName: queryName
            )
            return await withCheckedContinuation { (continuation: CheckedContinuation<[HKCategorySample], Never>) in
                let query = HKSampleQuery(
                    sampleType: sleepType,
                    predicate: predicate,
                    limit: HKObjectQueryNoLimit,
                    sortDescriptors: [
                        NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
                    ]
                ) { _, results, error in
                    StretheoLog.healthKit.debug("HK_QUERY_CALLBACK_FIRED: \(queryName)")
                    if let error {
                        StretheoLog.healthKit.debug("HK_QUERY_ERROR: \(queryName) - \(error.localizedDescription)")
                        continuation.resume(returning: [])
                        return
                    }
                    let count = results?.count ?? 0
                    StretheoLog.healthKit.debug("HK_QUERY_COMPLETE: \(queryName) - \(count) samples")
                    continuation.resume(returning: (results as? [HKCategorySample]) ?? [])
                }
                StretheoLog.healthKit.debug("HK_QUERY_EXECUTING: \(queryName) — calling healthStore.execute()")
                Self.healthStore.execute(query)
            }
        }

        let asleepValues: Set<Int> = [
            HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue,
            HKCategoryValueSleepAnalysis.asleepCore.rawValue,
            HKCategoryValueSleepAnalysis.asleepDeep.rawValue,
            HKCategoryValueSleepAnalysis.asleepREM.rawValue
        ]

        var total: TimeInterval = 0
        for sample in samples where asleepValues.contains(sample.value) {
            total += sample.endDate.timeIntervalSince(sample.startDate)
        }
        guard total > 0 else {
            return SleepMetrics(duration: nil, quality: nil)
        }
        let hours = total / 3600
        let quality = Int((min(hours / 8.0, 1.0) * 100).rounded())
        return SleepMetrics(duration: hours, quality: quality)
    }

    nonisolated private func hasRecentWorkout(queryName: String) async -> Bool {
        let workoutType = HKObjectType.workoutType()

        let count: Int = await HealthKitQueryRunner.run(
            queryName: queryName,
            defaultValue: 0
        ) {
            StretheoLog.healthKit.debug("HK_QUERY_START: \(queryName)")
            let now = Date()
            let predicate = HealthKitQueryPredicate.fromStartOfDay(now: now, queryName: queryName)
            return await withCheckedContinuation { (continuation: CheckedContinuation<Int, Never>) in
                let query = HKSampleQuery(
                    sampleType: workoutType,
                    predicate: predicate,
                    limit: 1,
                    sortDescriptors: [
                        NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
                    ]
                ) { _, samples, error in
                    StretheoLog.healthKit.debug("HK_QUERY_CALLBACK_FIRED: \(queryName)")
                    if let error {
                        StretheoLog.healthKit.debug("HK_QUERY_ERROR: \(queryName) - \(error.localizedDescription)")
                        continuation.resume(returning: 0)
                        return
                    }
                    let sampleCount = samples?.count ?? 0
                    StretheoLog.healthKit.debug("HK_QUERY_COMPLETE: \(queryName) - \(sampleCount) samples")
                    continuation.resume(returning: sampleCount)
                }
                StretheoLog.healthKit.debug("HK_QUERY_EXECUTING: \(queryName) — calling healthStore.execute()")
                Self.healthStore.execute(query)
            }
        }
        return count > 0
    }

    private static func insertQuantity(
        _ identifier: HKQuantityTypeIdentifier,
        into types: inout Set<HKObjectType>
    ) {
        if let type = HKQuantityType.quantityType(forIdentifier: identifier) {
            types.insert(type)
        }
    }

}

/// UserDefaults anchor persistence callable from HealthKit query callbacks (nonisolated).
/// PRIVACY FIX: stores only HKQueryAnchor bytes — never raw HRV sample values.
private enum HRVQueryAnchorStorage {
    nonisolated static let defaultsKey = "hrvQueryAnchor"

    nonisolated static func load() -> HKQueryAnchor? {
        guard let data = UserDefaults.standard.data(forKey: defaultsKey) else { return nil }
        return try? NSKeyedUnarchiver.unarchivedObject(ofClass: HKQueryAnchor.self, from: data)
    }

    nonisolated static func save(_ anchor: HKQueryAnchor) {
        guard let data = try? NSKeyedArchiver.archivedData(withRootObject: anchor, requiringSecureCoding: true) else {
            return
        }
        UserDefaults.standard.set(data, forKey: defaultsKey)
    }
}
