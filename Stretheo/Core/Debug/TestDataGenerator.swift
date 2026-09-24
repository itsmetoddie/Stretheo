//
//  TestDataGenerator.swift
//  Stretheo
//

#if DEBUG
import Foundation
import SwiftData

@MainActor
struct TestDataGenerator {
    static func generate(modelContext: ModelContext) async {
        let calendar = Calendar.current
        let now = Date()
        let profile = try? RepositoryHelpers.fetchOrCreateUserProfile(in: modelContext)

        for dayOffset in 0..<30 {
            guard let day = calendar.date(byAdding: .day, value: -dayOffset, to: now) else { continue }

            let measurementTimes = realisticTimes(for: day, calendar: calendar)
            var dayStressLevels: [Int] = []

            for time in measurementTimes {
                let stressLevel = realisticStressLevel(for: time, calendar: calendar)
                dayStressLevels.append(stressLevel)
                let category = StressCategory.from(level: stressLevel)
                let trigger: TriggerType = Bool.random() ? .automaticWatch : .automatic

                let measurement = StressMeasurement(
                    stressLevel: stressLevel,
                    stressCategory: category,
                    triggerType: trigger,
                    measuredAt: time,
                    createdAt: time,
                    userProfile: profile
                )

                let snapshot = HealthSnapshot(
                    hrv: Double.random(in: stressLevel > 65 ? 10...25 : 25...60),
                    restingHeartRate: Double.random(in: stressLevel > 65 ? 75...95 : 55...75),
                    currentHeartRate: Double.random(in: stressLevel > 65 ? 80...110 : 60...85),
                    respiratoryRate: Double.random(in: 12...20),
                    wristTemperature: Double.random(in: 35.5...37.2),
                    activityType: ["HKWorkoutActivityTypeWalking", "HKWorkoutActivityTypeRunning", "none"].randomElement(),
                    sleepDuration: Double.random(in: 5...9),
                    sleepQualityScore: Int.random(in: stressLevel > 65 ? 40...65 : 65...95),
                    recordedAt: time
                )
                snapshot.measurement = measurement
                measurement.healthSnapshot = snapshot

                modelContext.insert(measurement)
                modelContext.insert(snapshot)
            }

            if Bool.random() || dayOffset < 7 {
                guard let eveningTime = calendar.date(
                    bySettingHour: Int.random(in: 18...22),
                    minute: Int.random(in: 0...59),
                    second: 0,
                    of: day
                ) else { continue }

                let avgStress = dayStressLevels.reduce(0, +) / max(1, dayStressLevels.count)
                let moodScore = moodFromStress(avgStress)

                let mood = MoodEntry(
                    moodScore: moodScore,
                    moodWord: moodWord(for: moodScore),
                    entryDate: eveningTime,
                    createdAt: eveningTime,
                    userProfile: profile
                )
                modelContext.insert(mood)
            }
        }

        try? modelContext.save()
    }

    static func clear(modelContext: ModelContext) async {
        try? modelContext.delete(model: StressMeasurement.self)
        try? modelContext.delete(model: HealthSnapshot.self)
        try? modelContext.delete(model: MoodEntry.self)
        try? modelContext.delete(model: NotificationLog.self)
        try? modelContext.save()
    }

    // MARK: - Helpers

    private static func realisticTimes(for day: Date, calendar: Calendar) -> [Date] {
        let slots: [(hour: Int, minuteRange: ClosedRange<Int>)] = [
            (8, 0...30),
            (13, 0...45),
            (20, 0...59),
        ]
        let count = Int.random(in: 1...3)
        return slots.prefix(count).compactMap { slot in
            calendar.date(
                bySettingHour: slot.hour,
                minute: Int.random(in: slot.minuteRange),
                second: 0,
                of: day
            )
        }
    }

    private static func realisticStressLevel(for date: Date, calendar: Calendar) -> Int {
        let hour = calendar.component(.hour, from: date)
        let weekday = calendar.component(.weekday, from: date)
        let isWeekend = weekday == 1 || weekday == 7

        var base: Int
        switch hour {
        case 6...9: base = Int.random(in: 30...55)
        case 10...12: base = Int.random(in: 45...70)
        case 13...15: base = Int.random(in: 40...65)
        case 16...19: base = Int.random(in: 50...75)
        case 20...22: base = Int.random(in: 25...50)
        default: base = Int.random(in: 20...40)
        }

        if isWeekend { base = max(20, base - 15) }

        let spike = Int.random(in: -10...15)
        return min(100, max(0, base + spike))
    }

    private static func moodFromStress(_ stress: Int) -> Int {
        switch stress {
        case 0..<34: return Int.random(in: 4...5)
        case 34..<55: return Int.random(in: 3...4)
        case 55..<70: return Int.random(in: 2...3)
        default: return Int.random(in: 1...2)
        }
    }

    private static func moodWord(for score: Int) -> String {
        switch score {
        case 5: return ["Great", "Excellent", "Wonderful", "Fantastic"].randomElement()!
        case 4: return ["Good", "Pretty good", "Calm", "Relaxed"].randomElement()!
        case 3: return ["Okay", "Neutral", "Alright", "So-so"].randomElement()!
        case 2: return ["Tired", "Stressed", "Anxious", "Tense"].randomElement()!
        default: return ["Overwhelmed", "Exhausted", "Very stressed", "Burned out"].randomElement()!
        }
    }
}
#endif
