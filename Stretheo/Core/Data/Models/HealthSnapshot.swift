//
//  HealthSnapshot.swift
//  Stretheo
//

import Foundation
import SwiftData

@Model
final class HealthSnapshot {
    var id: UUID = UUID()
    var hrv: Double?
    var restingHeartRate: Double?
    var currentHeartRate: Double?
    var respiratoryRate: Double?
    var wristTemperature: Double?
    var activityType: String?
    var sleepDuration: Double?
    var sleepQualityScore: Int?
    var recordedAt: Date = Date()
    var cloudKitRecordID: String?

    var measurement: StressMeasurement?

    init(
        id: UUID = UUID(),
        hrv: Double? = nil,
        restingHeartRate: Double? = nil,
        currentHeartRate: Double? = nil,
        respiratoryRate: Double? = nil,
        wristTemperature: Double? = nil,
        activityType: String? = nil,
        sleepDuration: Double? = nil,
        sleepQualityScore: Int? = nil,
        recordedAt: Date = Date(),
        cloudKitRecordID: String? = nil
    ) {
        self.id = id
        self.hrv = hrv
        self.restingHeartRate = restingHeartRate
        self.currentHeartRate = currentHeartRate
        self.respiratoryRate = respiratoryRate
        self.wristTemperature = wristTemperature
        self.activityType = activityType
        self.sleepDuration = sleepDuration
        self.sleepQualityScore = sleepQualityScore.map { min(max($0, 0), 100) }
        self.recordedAt = recordedAt
        self.cloudKitRecordID = cloudKitRecordID
    }

    /// Builds a snapshot from algorithm input at measurement time.
    convenience init(from input: HealthInput, recordedAt: Date = Date()) {
        self.init(
            hrv: input.hrv,
            restingHeartRate: input.restingHeartRate,
            currentHeartRate: input.currentHeartRate,
            respiratoryRate: input.respiratoryRate,
            wristTemperature: input.wristTemperature,
            activityType: input.activityType,
            sleepDuration: input.sleepDuration,
            sleepQualityScore: input.sleepQualityScore,
            recordedAt: recordedAt
        )
    }
}
