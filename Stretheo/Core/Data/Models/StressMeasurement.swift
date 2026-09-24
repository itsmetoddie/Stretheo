//
//  StressMeasurement.swift
//  Stretheo
//

import Foundation
import SwiftData

@Model
final class StressMeasurement {
    #Index<StressMeasurement>([\.measuredAt])

    var id: UUID = UUID()
    var stressLevel: Int = 0
    var stressCategoryRaw: String = ""
    var triggerTypeRaw: String = ""
    var measuredAt: Date = Date()
    var createdAt: Date = Date()
    var cloudKitRecordID: String?

    var userProfile: UserProfile?

    @Relationship(deleteRule: .cascade, inverse: \HealthSnapshot.measurement)
    var healthSnapshot: HealthSnapshot?

    @Relationship(deleteRule: .nullify, inverse: \NotificationLog.triggeredByMeasurement)
    var triggeredNotification: NotificationLog?

    var stressCategory: StressCategory {
        get { StressCategory(rawValue: stressCategoryRaw) ?? .low }
        set { stressCategoryRaw = newValue.rawValue }
    }

    var triggerType: TriggerType {
        get { TriggerType(rawValue: triggerTypeRaw) ?? .automatic }
        set { triggerTypeRaw = newValue.rawValue }
    }

    init(
        id: UUID = UUID(),
        stressLevel: Int,
        stressCategory: StressCategory,
        triggerType: TriggerType,
        measuredAt: Date = Date(),
        createdAt: Date = Date(),
        cloudKitRecordID: String? = nil,
        userProfile: UserProfile? = nil,
        healthSnapshot: HealthSnapshot? = nil,
        triggeredNotification: NotificationLog? = nil
    ) {
        self.id = id
        self.stressLevel = min(max(stressLevel, 0), 100)
        self.stressCategoryRaw = stressCategory.rawValue
        self.triggerTypeRaw = triggerType.rawValue
        self.measuredAt = measuredAt
        self.createdAt = createdAt
        self.cloudKitRecordID = cloudKitRecordID
        self.userProfile = userProfile
        self.healthSnapshot = healthSnapshot
        self.triggeredNotification = triggeredNotification
    }
}
