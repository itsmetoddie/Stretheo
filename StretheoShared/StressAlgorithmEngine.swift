//
//  StressAlgorithmEngine.swift
//  StretheoShared
//
//  Pure stress scoring — no HealthKit or persistence side effects.
//

import Foundation
import os

private enum StressAlgorithmLogging {
    nonisolated static func debugActivity(state: ActivityState, multiplier: Double) {
        Logger(subsystem: "com.zapreff.Stretheo", category: "StressAlgorithm")
            .debug(
                "activity classified as \(state.rawValue, privacy: .public); HR/HRV multiplier=\(multiplier, privacy: .public)"
            )
    }
}

/// Minutes after vigorous activity during which HR/HRV contributions ramp back to full weight.
nonisolated private let recoveryWindowMinutes: Double = 15

nonisolated private let restingHRHRVMultiplier: Double = 1.0
nonisolated private let lightHRHRVMultiplier: Double = 0.7
/// Temporary compromise: thesis design skips calculation entirely during vigorous activity,
/// but `compute(from:)` must remain non-optional until call sites are updated in a follow-up.
nonisolated private let vigorousHRHRVMultiplier: Double = 0.15

/// Tracks the most recent vigorous-activity timestamp across engine instances.
private enum VigorousActivityTracker {
    private nonisolated static let state = OSAllocatedUnfairLock(initialState: Optional<Date>.none)

    nonisolated static func recordVigorous(at date: Date = Date()) {
        state.withLock { $0 = date }
    }

    nonisolated static func lastVigorousTimestamp() -> Date? {
        state.withLock { $0 }
    }
}

struct StressAlgorithmEngine: Sendable {
    private struct WeightedMetric: Sendable {
        let weight: Double
        let stressContribution: Double?
    }

    func compute(from input: HealthInput) -> StressResult {
        let age = calibratedAge(month: input.birthMonth, year: input.birthYear)
        let ranges = StressReferenceRanges.forProfile(age: age, sex: input.sex)
        let heartRate = input.currentHeartRate ?? input.restingHeartRate
        let activityState = classifyActivity(
            activityType: input.activityType,
            currentHeartRate: heartRate,
            ranges: ranges
        )
        let hrHrvMultiplier = hrHRVContributionMultiplier(for: activityState)

        StressAlgorithmLogging.debugActivity(state: activityState, multiplier: hrHrvMultiplier)

        let metrics: [WeightedMetric] = [
            WeightedMetric(
                weight: StressAlgorithmWeights.hrv,
                stressContribution: scaledHRHRVContribution(
                    normalizeHRV(input.hrv, ranges: ranges),
                    multiplier: hrHrvMultiplier
                )
            ),
            WeightedMetric(
                weight: StressAlgorithmWeights.heartRate,
                stressContribution: scaledHRHRVContribution(
                    normalizeHeartRate(heartRate, ranges: ranges),
                    multiplier: hrHrvMultiplier
                )
            ),
            WeightedMetric(
                weight: StressAlgorithmWeights.respiratory,
                stressContribution: normalizeRespiratory(input.respiratoryRate, ranges: ranges)
            ),
            WeightedMetric(
                weight: StressAlgorithmWeights.sleep,
                stressContribution: normalizeSleep(duration: input.sleepDuration, quality: input.sleepQualityScore)
            ),
            WeightedMetric(
                weight: StressAlgorithmWeights.activityTemperature,
                stressContribution: normalizeActivityTemp(temperature: input.wristTemperature, activity: input.activityType)
            )
        ]

        let available = metrics.compactMap { metric -> (WeightedMetric, Double)? in
            guard let value = metric.stressContribution else { return nil }
            return (metric, value)
        }

        let level: Int
        let breakdown: [String]

        if available.isEmpty {
            level = 50
            breakdown = ["Insufficient health data"]
        } else {
            let totalWeight = available.reduce(0.0) { $0 + $1.0.weight }
            let score = available.reduce(0.0) { partial, item in
                partial + (item.0.weight / totalWeight) * item.1
            }
            level = Int((score * 100).rounded()).clamped(to: 0...100)
            breakdown = buildBreakdown(input: input, level: level, ranges: ranges)
        }

        return StressResult(
            level: level,
            category: StressCategory.from(level: level),
            breakdown: breakdown
        )
    }

    func classifyActivity(
        activityType: String?,
        currentHeartRate: Double?,
        ranges: StressReferenceRanges
    ) -> ActivityState {
        if isVigorousActivity(activityType: activityType, currentHeartRate: currentHeartRate, ranges: ranges) {
            VigorousActivityTracker.recordVigorous()
            return .vigorous
        }

        if isWithinRecoveryWindow() {
            return .recovery
        }

        if isLightActivity(activityType: activityType) {
            return .light
        }

        return .resting
    }

    private func isVigorousActivity(
        activityType: String?,
        currentHeartRate: Double?,
        ranges: StressReferenceRanges
    ) -> Bool {
        guard isActiveActivityType(activityType), let currentHeartRate else { return false }
        return currentHeartRate >= ranges.elevatedHR
    }

    /// HealthKitManager currently emits only `"active"` and `"rest"` via `deriveActivityType`.
    private func isActiveActivityType(_ activityType: String?) -> Bool {
        guard let activityType else { return false }
        let normalized = activityType.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return normalized == "active"
    }

    /// Light movement: active signal present but HR has not crossed the elevated bound.
    private func isLightActivity(activityType: String?) -> Bool {
        isActiveActivityType(activityType)
    }

    private func isWithinRecoveryWindow(referenceDate: Date = Date()) -> Bool {
        guard let lastVigorousAt = VigorousActivityTracker.lastVigorousTimestamp() else { return false }
        let elapsed = referenceDate.timeIntervalSince(lastVigorousAt)
        return elapsed >= 0 && elapsed < recoveryWindowMinutes * 60
    }

    private func hrHRVContributionMultiplier(for activityState: ActivityState, referenceDate: Date = Date()) -> Double {
        switch activityState {
        case .resting:
            return restingHRHRVMultiplier
        case .light:
            return lightHRHRVMultiplier
        case .vigorous:
            return vigorousHRHRVMultiplier
        case .recovery:
            guard let lastVigorousAt = VigorousActivityTracker.lastVigorousTimestamp() else {
                return restingHRHRVMultiplier
            }
            let windowSeconds = recoveryWindowMinutes * 60
            let elapsed = max(0, referenceDate.timeIntervalSince(lastVigorousAt))
            let progress = min(elapsed / windowSeconds, 1.0)
            return vigorousHRHRVMultiplier + (restingHRHRVMultiplier - vigorousHRHRVMultiplier) * progress
        }
    }

    private func scaledHRHRVContribution(_ contribution: Double?, multiplier: Double) -> Double? {
        guard let contribution else { return nil }
        return (contribution * multiplier).clamped(to: 0...1)
    }

    private func calibratedAge(month: Int, year: Int) -> Int {
        let calendar = Calendar.current
        var components = DateComponents()
        components.year = year
        components.month = min(max(month, 1), 12)
        components.day = 15
        guard let birth = calendar.date(from: components) else { return 30 }
        let years = calendar.dateComponents([.year], from: birth, to: Date()).year ?? 30
        return max(18, years)
    }

    private func normalizeHRV(_ hrv: Double?, ranges: StressReferenceRanges) -> Double? {
        guard let hrv else { return nil }
        if hrv >= ranges.hrvHigh { return 0.10 }
        if hrv <= ranges.hrvLow { return 0.95 }
        let span = ranges.hrvHigh - ranges.hrvLow
        guard span > 0 else { return 0.5 }
        return ((ranges.hrvHigh - hrv) / span).clamped(to: 0...1)
    }

    private func normalizeHeartRate(_ bpm: Double?, ranges: StressReferenceRanges) -> Double? {
        guard let bpm else { return nil }
        if bpm <= ranges.restingHRBaseline { return 0.15 }
        if bpm >= ranges.elevatedHR { return 0.90 }
        let span = ranges.elevatedHR - ranges.restingHRBaseline
        guard span > 0 else { return 0.5 }
        return ((bpm - ranges.restingHRBaseline) / span).clamped(to: 0...1)
    }

    private func normalizeRespiratory(_ rate: Double?, ranges: StressReferenceRanges) -> Double? {
        guard let rate else { return nil }
        if rate <= ranges.respiratoryNormal { return 0.20 }
        if rate >= ranges.respiratoryHigh { return 0.85 }
        let span = ranges.respiratoryHigh - ranges.respiratoryNormal
        guard span > 0 else { return 0.5 }
        return ((rate - ranges.respiratoryNormal) / span).clamped(to: 0...1)
    }

    private func normalizeSleep(duration: Double?, quality: Int?) -> Double? {
        if let quality {
            return (1.0 - Double(quality) / 100.0).clamped(to: 0...1)
        }
        guard let duration else { return nil }
        if duration >= 7.5 { return 0.15 }
        if duration <= 5.0 { return 0.90 }
        return ((7.5 - duration) / 2.5).clamped(to: 0...1)
    }

    private func normalizeActivityTemp(temperature: Double?, activity: String?) -> Double? {
        var parts: [Double] = []
        if let temperature {
            let magnitude = abs(temperature)
            parts.append((magnitude / 1.5).clamped(to: 0...1) * 0.6)
        }
        if let activity, isActiveActivityType(activity) {
            parts.append(0.45)
        }
        guard !parts.isEmpty else { return nil }
        return parts.reduce(0, +) / Double(parts.count)
    }

    private func buildBreakdown(
        input: HealthInput,
        level: Int,
        ranges: StressReferenceRanges
    ) -> [String] {
        var hints: [String] = []

        if let hrv = input.hrv, hrv < ranges.hrvLow + 5 {
            hints.append("HRV below your typical range")
        }
        if let hr = input.currentHeartRate ?? input.restingHeartRate, hr > ranges.restingHRBaseline + 20 {
            hints.append("Heart rate elevated")
        }
        if let sleep = input.sleepDuration, sleep < 6 {
            hints.append("Sleep duration low")
        }
        if let quality = input.sleepQualityScore, quality < 50 {
            hints.append("Sleep quality low")
        }
        if let resp = input.respiratoryRate, resp > ranges.respiratoryHigh - 1 {
            hints.append("Respiratory rate elevated")
        }

        if hints.isEmpty {
            hints.append("Stress level \(level)")
        }
        return hints
    }
}

private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
