//
//  UserProfile.swift
//  Stretheo
//

import Foundation
import SwiftData

@Model
final class UserProfile {
    var id: UUID = UUID()
    var displayName: String = ""
    var email: String?
    var birthMonth: Int = 0
    var birthYear: Int = 0
    var sexRaw: String = ""
    var notifThreshold: Int = 0
    var quietHoursStart: Date = Date()
    var quietHoursEnd: Date = Date()
    var iCloudSyncEnabled: Bool = false
    var cloudKitRecordID: String?

    @Relationship(deleteRule: .cascade, inverse: \StressMeasurement.userProfile)
    var measurements: [StressMeasurement]? = []

    @Relationship(deleteRule: .cascade, inverse: \MoodEntry.userProfile)
    var moodEntries: [MoodEntry]? = []

    @Relationship(deleteRule: .cascade, inverse: \NotificationLog.userProfile)
    var notificationLogs: [NotificationLog]? = []

    @Relationship(deleteRule: .cascade, inverse: \ExportLog.userProfile)
    var exportLogs: [ExportLog]? = []

    var sex: ProfileSex {
        get { ProfileSex(rawValue: sexRaw) ?? .other }
        set { sexRaw = newValue.rawValue }
    }

    init(
        id: UUID = UUID(),
        displayName: String = "",
        email: String? = nil,
        birthMonth: Int = 1,
        birthYear: Int = 1990,
        sex: ProfileSex = .other,
        notifThreshold: Int = NotificationPolicy.defaultStressAlertThreshold,
        quietHoursStart: Date = UserProfile.defaultQuietStart,
        quietHoursEnd: Date = UserProfile.defaultQuietEnd,
        iCloudSyncEnabled: Bool = false,
        cloudKitRecordID: String? = nil
    ) {
        self.id = id
        self.displayName = displayName
        self.email = email
        self.birthMonth = min(max(birthMonth, 1), 12)
        self.birthYear = birthYear
        self.sexRaw = sex.rawValue
        self.notifThreshold = min(max(notifThreshold, 0), 100)
        self.quietHoursStart = quietHoursStart
        self.quietHoursEnd = quietHoursEnd
        self.iCloudSyncEnabled = iCloudSyncEnabled
        self.cloudKitRecordID = cloudKitRecordID
    }

    static var defaultQuietStart: Date {
        NotificationPolicy.defaultQuietHoursStart()
    }

    static var defaultQuietEnd: Date {
        NotificationPolicy.defaultQuietHoursEnd()
    }
}
