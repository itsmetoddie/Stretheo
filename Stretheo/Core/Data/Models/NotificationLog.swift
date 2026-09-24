//
//  NotificationLog.swift
//  Stretheo
//

import Foundation
import SwiftData

@Model
final class NotificationLog {
    #Index<NotificationLog>([\.sentAt])

    var id: UUID = UUID()
    var stressLevelAtTrigger: Int = 0
    var messageText: String = ""
    var sentAt: Date = Date()
    var isRead: Bool = false
    var cloudKitRecordID: String?
    /// Originating device for the alert: `iphone` or `watch`.
    var sourceRaw: String = NotificationSource.iphone.rawValue

    var userProfile: UserProfile? = nil
    var triggeredByMeasurement: StressMeasurement? = nil

    init(
        id: UUID = UUID(),
        stressLevelAtTrigger: Int,
        messageText: String,
        sentAt: Date = Date(),
        isRead: Bool = false,
        cloudKitRecordID: String? = nil,
        source: NotificationSource = .iphone,
        userProfile: UserProfile? = nil,
        triggeredByMeasurement: StressMeasurement? = nil
    ) {
        self.id = id
        self.stressLevelAtTrigger = min(max(stressLevelAtTrigger, 0), 100)
        self.messageText = messageText
        self.sentAt = sentAt
        self.isRead = isRead
        self.cloudKitRecordID = cloudKitRecordID
        self.sourceRaw = source.rawValue
        self.userProfile = userProfile
        self.triggeredByMeasurement = triggeredByMeasurement
    }
}
