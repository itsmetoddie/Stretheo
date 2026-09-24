//
//  InsightEngine.swift
//  Stretheo
//
//  Pure correlation insights from stress, health, and mood history (last 30 days).
//

import Foundation

struct Insight: Identifiable, Sendable, Equatable {
    let id: UUID
    let title: String
    let body: String
    let icon: String
    let confidence: Double
}

struct InsightEngineInput: Sendable {
    struct Measurement: Sendable {
        let stressLevel: Int
        let measuredAt: Date
    }

    struct Snapshot: Sendable {
        let sleepDuration: Double?
        let hrv: Double?
        let recordedAt: Date
    }

    struct Mood: Sendable {
        let moodScore: Int
        let entryDate: Date
    }

    let measurements: [Measurement]
    let snapshots: [Snapshot]
    let moods: [Mood]
    let referenceDate: Date
}

enum InsightEngine {
    nonisolated static func compute(input: InsightEngineInput) -> [Insight] {
        let lookbackDays = 30
        let shortSleepHours = 6.0
        let highStressLevel = 65
        let lowMoodScore = 2
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        guard let cutoff = calendar.date(byAdding: .day, value: -lookbackDays, to: input.referenceDate) else {
            return [notEnoughDataInsight()]
        }

        let measurements = input.measurements.filter { $0.measuredAt >= cutoff }
        let snapshots = input.snapshots.filter { $0.recordedAt >= cutoff }
        let moods = input.moods.filter { $0.entryDate >= cutoff }

        if measurements.count < 5 {
            return [notEnoughDataInsight()]
        }

        var insights: [Insight] = []

        if let sleep = sleepStressInsight(
            measurements: measurements,
            snapshots: snapshots,
            calendar: calendar,
            shortSleepHours: shortSleepHours
        ) {
            insights.append(sleep)
        }
        if let timeOfDay = timeOfDayInsight(measurements: measurements, calendar: calendar) {
            insights.append(timeOfDay)
        }
        if let moodStress = moodStressInsight(
            measurements: measurements,
            moods: moods,
            calendar: calendar,
            highStressLevel: highStressLevel,
            lowMoodScore: lowMoodScore
        ) {
            insights.append(moodStress)
        }
        if let sustained = sustainedStressMoodInsight(
            measurements: measurements,
            moods: moods,
            calendar: calendar,
            highStressLevel: highStressLevel
        ) {
            insights.append(sustained)
        }
        if let hrv = hrvTrendInsight(snapshots: snapshots, referenceDate: input.referenceDate, calendar: calendar) {
            insights.append(hrv)
        }

        if insights.isEmpty {
            return [notEnoughDataInsight()]
        }

        return Array(insights.sorted { $0.confidence > $1.confidence }.prefix(3))
    }

    // MARK: - Correlations

    private nonisolated static func sleepStressInsight(
        measurements: [InsightEngineInput.Measurement],
        snapshots: [InsightEngineInput.Snapshot],
        calendar: Calendar,
        shortSleepHours: Double
    ) -> Insight? {
        var shortNextDayLevels: [Int] = []
        var adequateNextDayLevels: [Int] = []

        let measurementsByDay = dailyAverageStress(measurements: measurements, calendar: calendar)

        for snapshot in snapshots {
            guard let sleep = snapshot.sleepDuration, sleep > 0 else { continue }
            let wakeDay = calendar.startOfDay(for: snapshot.recordedAt)
            guard let nextDay = calendar.date(byAdding: .day, value: 1, to: wakeDay) else { continue }
            guard let level = measurementsByDay[nextDay] else { continue }

            if sleep < shortSleepHours {
                shortNextDayLevels.append(level)
            } else {
                adequateNextDayLevels.append(level)
            }
        }

        guard shortNextDayLevels.count >= 4, !adequateNextDayLevels.isEmpty else { return nil }

        let shortAvg = average(shortNextDayLevels)
        let adequateAvg = average(adequateNextDayLevels)
        let diff = shortAvg - adequateAvg
        guard diff > 10 else { return nil }

        let pct = percentIncrease(from: adequateAvg, to: shortAvg)

        return Insight(
            id: UUID(),
            title: "Your stress is \(pct)% higher after short nights",
            body: "On nights with under 6 hours of sleep, your next-day stress averages \(diff) points higher than after a good night's rest.",
            icon: "bed.double.fill",
            confidence: min(0.92, 0.65 + Double(shortNextDayLevels.count) * 0.04)
        )
    }

    private nonisolated static func timeOfDayInsight(
        measurements: [InsightEngineInput.Measurement],
        calendar: Calendar
    ) -> Insight? {
        enum Bucket: String, CaseIterable {
            case morning = "Morning"
            case afternoon = "Afternoon"
            case evening = "Evening"
            case night = "Night"
        }

        var levelsByBucket: [Bucket: [Int]] = [:]
        for measurement in measurements {
            let hour = calendar.component(.hour, from: measurement.measuredAt)
            let bucket: Bucket
            switch hour {
            case 6..<12: bucket = .morning
            case 12..<17: bucket = .afternoon
            case 17..<22: bucket = .evening
            default: bucket = .night
            }
            levelsByBucket[bucket, default: []].append(measurement.stressLevel)
        }

        let averages = Bucket.allCases.compactMap { bucket -> (Bucket, Int)? in
            guard let levels = levelsByBucket[bucket], !levels.isEmpty else { return nil }
            return (bucket, average(levels))
        }

        guard averages.count >= 2,
              let peak = averages.max(by: { $0.1 < $1.1 }),
              let low = averages.min(by: { $0.1 < $1.1 }),
              peak.1 - low.1 >= 8,
              (levelsByBucket[peak.0]?.count ?? 0) >= 5
        else { return nil }

        let diff = peak.1 - low.1
        let peakLabel = peak.0.rawValue.lowercased()
        let windDownHint = peak.0 == .evening
            ? " Consider a wind-down routine between 17:00 and 22:00."
            : ""

        return Insight(
            id: UUID(),
            title: "Your stress peaks in the \(peak.0.rawValue)",
            body: "Your \(peakLabel) readings average \(diff) points higher than the rest of the day.\(windDownHint)",
            icon: "clock.fill",
            confidence: min(0.88, 0.6 + Double(levelsByBucket[peak.0]?.count ?? 0) * 0.03)
        )
    }

    private nonisolated static func moodStressInsight(
        measurements: [InsightEngineInput.Measurement],
        moods: [InsightEngineInput.Mood],
        calendar: Calendar,
        highStressLevel: Int,
        lowMoodScore: Int
    ) -> Insight? {
        let stressByDay = dailyAverageStress(measurements: measurements, calendar: calendar)
        var moodByDay: [Date: [Int]] = [:]
        for mood in moods {
            let day = calendar.startOfDay(for: mood.entryDate)
            moodByDay[day, default: []].append(mood.moodScore)
        }

        var highStressMoods: [Int] = []
        var calmMoods: [Int] = []

        for (day, stress) in stressByDay {
            guard let scores = moodByDay[day], let moodAvg = averageOptional(scores) else { continue }
            if stress >= highStressLevel {
                highStressMoods.append(moodAvg)
            } else {
                calmMoods.append(moodAvg)
            }
        }

        guard highStressMoods.count >= 5, !calmMoods.isEmpty else { return nil }

        let highAvg = average(highStressMoods)
        let calmAvg = average(calmMoods)
        guard highAvg <= lowMoodScore, highAvg < calmAvg else { return nil }

        return Insight(
            id: UUID(),
            title: "High stress affects your mood",
            body: "On high-stress days your mood rating averages \(highAvg)/5, compared to \(calmAvg)/5 on calmer days.",
            icon: "face.smiling.inverse",
            confidence: min(0.86, 0.62 + Double(highStressMoods.count) * 0.03)
        )
    }

    private nonisolated static func sustainedStressMoodInsight(
        measurements: [InsightEngineInput.Measurement],
        moods: [InsightEngineInput.Mood],
        calendar: Calendar,
        highStressLevel: Int
    ) -> Insight? {
        let stressByDay = dailyAverageStress(measurements: measurements, calendar: calendar)
        let sortedDays = stressByDay.keys.sorted()
        guard !sortedDays.isEmpty else { return nil }

        var moodByDay: [Date: Int] = [:]
        for mood in moods {
            let day = calendar.startOfDay(for: mood.entryDate)
            let existing = moodByDay[day] ?? mood.moodScore
            moodByDay[day] = max(existing, mood.moodScore)
        }

        let baselineMoods = Array(moodByDay.values)
        guard !baselineMoods.isEmpty else { return nil }
        let baseline = average(baselineMoods)

        var runMoodDrops: [Int] = []
        var index = 0
        while index < sortedDays.count {
            var runLength = 0
            while index < sortedDays.count, stressByDay[sortedDays[index]]! >= highStressLevel {
                runLength += 1
                index += 1
            }
            if runLength >= 2 {
                let runEnd = index - 1
                let runStart = runEnd - runLength + 1
                for offset in 0..<runLength {
                    let day = sortedDays[runStart + offset]
                    if let mood = moodByDay[day] {
                        runMoodDrops.append(baseline - mood)
                    }
                }
            }
            if runLength == 0 {
                index += 1
            }
        }

        guard runMoodDrops.count >= 3 else { return nil }

        let avgDrop = average(runMoodDrops.filter { $0 > 0 })
        guard avgDrop > 0 else { return nil }

        return Insight(
            id: UUID(),
            title: "Sustained stress weighs on your mood",
            body: "After 2 or more high-stress days in a row, your mood tends to drop by an average of \(avgDrop) points.",
            icon: "arrow.trend.down",
            confidence: min(0.8, 0.55 + Double(runMoodDrops.count) * 0.04)
        )
    }

    private nonisolated static func hrvTrendInsight(
        snapshots: [InsightEngineInput.Snapshot],
        referenceDate: Date,
        calendar: Calendar
    ) -> Insight? {
        guard let recentStart = calendar.date(byAdding: .day, value: -7, to: referenceDate),
              let priorStart = calendar.date(byAdding: .day, value: -14, to: referenceDate)
        else { return nil }

        let recentHRV = snapshots
            .filter { $0.recordedAt >= recentStart && $0.hrv != nil }
            .compactMap(\.hrv)
        let priorHRV = snapshots
            .filter { $0.recordedAt >= priorStart && $0.recordedAt < recentStart && $0.hrv != nil }
            .compactMap(\.hrv)

        guard recentHRV.count >= 5, priorHRV.count >= 5 else { return nil }

        let recentAvg = recentHRV.reduce(0, +) / Double(recentHRV.count)
        let priorAvg = priorHRV.reduce(0, +) / Double(priorHRV.count)
        guard priorAvg > 0 else { return nil }

        let improvement = ((recentAvg - priorAvg) / priorAvg) * 100
        guard improvement >= 10 else { return nil }

        let pct = Int(improvement.rounded())

        return Insight(
            id: UUID(),
            title: "Your HRV is improving",
            body: "Your heart rate variability has increased \(pct)% over the past week — a sign your nervous system is recovering well.",
            icon: "waveform.path.ecg",
            confidence: min(0.78, 0.5 + Double(recentHRV.count + priorHRV.count) * 0.02)
        )
    }

    private nonisolated static func notEnoughDataInsight() -> Insight {
        Insight(
            id: UUID(),
            title: "Keep measuring to unlock insights",
            body: "Stretheo needs at least a week of check-ins to detect patterns in your stress and mood. You're on your way.",
            icon: "sparkles",
            confidence: 0.0
        )
    }

    // MARK: - Helpers

    private nonisolated static func dailyAverageStress(
        measurements: [InsightEngineInput.Measurement],
        calendar: Calendar
    ) -> [Date: Int] {
        var buckets: [Date: [Int]] = [:]
        for measurement in measurements {
            let day = calendar.startOfDay(for: measurement.measuredAt)
            buckets[day, default: []].append(measurement.stressLevel)
        }
        var result: [Date: Int] = [:]
        for (day, levels) in buckets {
            result[day] = average(levels)
        }
        return result
    }

    private nonisolated static func average(_ values: [Int]) -> Int {
        guard !values.isEmpty else { return 0 }
        return values.reduce(0, +) / values.count
    }

    private nonisolated static func averageOptional(_ values: [Int]) -> Int? {
        guard !values.isEmpty else { return nil }
        return average(values)
    }

    private nonisolated static func percentIncrease(from baseline: Int, to value: Int) -> Int {
        guard baseline > 0 else { return 0 }
        return Int((Double(value - baseline) / Double(baseline) * 100).rounded())
    }
}
