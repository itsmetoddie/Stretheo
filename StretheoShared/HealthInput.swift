//
//  HealthInput.swift
//  StretheoShared
//

import Foundation

enum ActivityState: String, Sendable {
    case resting
    case light
    case vigorous
    case recovery
}

struct HealthInput: Sendable, Equatable {
    var hrv: Double?
    var restingHeartRate: Double?
    var currentHeartRate: Double?
    var respiratoryRate: Double?
    var wristTemperature: Double?
    var activityType: String?
    var sleepDuration: Double?
    var sleepQualityScore: Int?

    var birthMonth: Int
    var birthYear: Int
    var sex: ProfileSex

    static let empty = HealthInput(
        hrv: nil,
        restingHeartRate: nil,
        currentHeartRate: nil,
        respiratoryRate: nil,
        wristTemperature: nil,
        activityType: nil,
        sleepDuration: nil,
        sleepQualityScore: nil,
        birthMonth: 1,
        birthYear: 1990,
        sex: .other
    )
}
