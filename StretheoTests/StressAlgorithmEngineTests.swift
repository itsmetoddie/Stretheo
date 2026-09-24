//
//  StressAlgorithmEngineTests.swift
//  StretheoTests
//

import Testing
@testable import Stretheo

@MainActor
struct StressAlgorithmEngineTests {
    @Test func computesModerateStressWithMixedSignals() {
        let engine = StressAlgorithmEngine()
        let input = HealthInput(
            hrv: 35,
            restingHeartRate: 72,
            currentHeartRate: 88,
            respiratoryRate: 16,
            wristTemperature: nil,
            activityType: "rest",
            sleepDuration: 6,
            sleepQualityScore: 55,
            birthMonth: 6,
            birthYear: 1990,
            sex: .female
        )
        let result = engine.compute(from: input)
        #expect(result.level >= 30)
        #expect(result.level <= 85)
        #expect(!result.breakdown.isEmpty)
    }

    @Test func handlesMissingMetrics() {
        let engine = StressAlgorithmEngine()
        let result = engine.compute(from: .empty)
        #expect(result.level == 50)
    }

    @Test func lowStressWithStrongHRVAndSleep() {
        let engine = StressAlgorithmEngine()
        let input = HealthInput(
            hrv: 70,
            restingHeartRate: 58,
            currentHeartRate: 62,
            respiratoryRate: 14,
            wristTemperature: 0.1,
            activityType: "rest",
            sleepDuration: 8,
            sleepQualityScore: 90,
            birthMonth: 3,
            birthYear: 1995,
            sex: .male
        )
        let result = engine.compute(from: input)
        #expect(result.level < 40)
        #expect(result.category == .low)
    }

    @Test func highStressWithPoorSignals() {
        let engine = StressAlgorithmEngine()
        let input = HealthInput(
            hrv: 22,
            restingHeartRate: 78,
            currentHeartRate: 102,
            respiratoryRate: 21,
            wristTemperature: 1.2,
            activityType: "rest",
            sleepDuration: 4.5,
            sleepQualityScore: 30,
            birthMonth: 1,
            birthYear: 1980,
            sex: .female
        )
        let result = engine.compute(from: input)
        #expect(result.level >= 60)
        #expect(result.category == .high || result.category == .moderate)
    }
}
