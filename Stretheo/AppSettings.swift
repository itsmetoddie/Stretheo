//
//  AppSettings.swift
//  Stretheo
//

import Foundation
import SwiftUI

enum AppSettingsKey {
    static let hasCompletedOnboarding = "hasCompletedOnboarding"
    static let appearanceMode = "appearanceMode"
    static let lastNotifiedAt = "lastNotifiedAt"
    static let healthSyncEnabled = "healthSyncEnabled"
    static let notificationsEnabled = "notificationsEnabled"
    static let customHistoryStart = "customHistoryStart"
    static let customHistoryEnd = "customHistoryEnd"
    static let iCloudSyncEnabled = "icloud_sync_enabled"
    static let legacyICloudSyncEnabled = "iCloudSyncEnabled"
    static let lastICloudStatusCheck = "lastICloudStatusCheck"
    static let quietHoursStart = "quietHoursStart"
    static let quietHoursEnd = "quietHoursEnd"
    static let stressAlertThreshold = "stressAlertThreshold"
    static let moodReminderEnabled = "mood_reminder_enabled"
    static let moodReminderTime = "mood_reminder_time"
    static let notificationDailyCount = "notificationDailyCount"
    static let notificationCountResetDay = "notificationCountResetDay"
    static let hrvQueryAnchor = "hrvQueryAnchor"
    static let healthKitBackgroundDeliveryEnabled = "healthKitBackgroundDeliveryEnabled"
    static let hasRequestedHealthKitReadAuthorization = "hasRequestedHealthKitReadAuthorization"
    static let lastBGTaskFallbackAt = "lastBGTaskFallbackAt"
    static let profileAvatarJPEG = "profileAvatarJPEG"
    static let moodDatePickerDiscovered = "moodDatePickerDiscovered"
}

enum AppSettings {
    private static let defaults = UserDefaults.standard

    /// Migrates the legacy `iCloudSyncEnabled` key to `icloud_sync_enabled` once.
    static func migrateLegacyICloudSyncKeyIfNeeded() {
        guard defaults.object(forKey: AppSettingsKey.iCloudSyncEnabled) == nil,
              defaults.object(forKey: AppSettingsKey.legacyICloudSyncEnabled) != nil else {
            return
        }
        defaults.set(
            defaults.bool(forKey: AppSettingsKey.legacyICloudSyncEnabled),
            forKey: AppSettingsKey.iCloudSyncEnabled
        )
    }

    static var hasCompletedOnboarding: Bool {
        get { defaults.bool(forKey: AppSettingsKey.hasCompletedOnboarding) }
        set { defaults.set(newValue, forKey: AppSettingsKey.hasCompletedOnboarding) }
    }

    static var appearanceMode: AppearanceMode {
        get {
            AppearanceMode(rawValue: defaults.string(forKey: AppSettingsKey.appearanceMode) ?? "") ?? .system
        }
        set { defaults.set(newValue.rawValue, forKey: AppSettingsKey.appearanceMode) }
    }

    static var lastNotifiedAt: Date? {
        get { defaults.object(forKey: AppSettingsKey.lastNotifiedAt) as? Date }
        set { defaults.set(newValue, forKey: AppSettingsKey.lastNotifiedAt) }
    }

    static var healthSyncEnabled: Bool {
        get { defaults.bool(forKey: AppSettingsKey.healthSyncEnabled) }
        set { defaults.set(newValue, forKey: AppSettingsKey.healthSyncEnabled) }
    }

    /// Tracks whether iOS HRV `enableBackgroundDelivery` has been registered this install.
    static var healthKitBackgroundDeliveryEnabled: Bool {
        get { defaults.bool(forKey: AppSettingsKey.healthKitBackgroundDeliveryEnabled) }
        set { defaults.set(newValue, forKey: AppSettingsKey.healthKitBackgroundDeliveryEnabled) }
    }

    /// Set after the first `HKHealthStore.requestAuthorization` call this install.
    /// Read-type status remains `.notDetermined` by Apple's privacy design — this flag tracks prompt completion, not grant state.
    static var hasRequestedHealthKitReadAuthorization: Bool {
        get { defaults.bool(forKey: AppSettingsKey.hasRequestedHealthKitReadAuthorization) }
        set { defaults.set(newValue, forKey: AppSettingsKey.hasRequestedHealthKitReadAuthorization) }
    }

    static func migrateHealthKitAuthorizationFlagIfNeeded() {
        if healthSyncEnabled, !hasRequestedHealthKitReadAuthorization {
            hasRequestedHealthKitReadAuthorization = true
        }
    }

    static var notificationsEnabled: Bool {
        get { defaults.bool(forKey: AppSettingsKey.notificationsEnabled) }
        set { defaults.set(newValue, forKey: AppSettingsKey.notificationsEnabled) }
    }

    static var customHistoryStart: Date? {
        get { defaults.object(forKey: AppSettingsKey.customHistoryStart) as? Date }
        set { defaults.set(newValue, forKey: AppSettingsKey.customHistoryStart) }
    }

    static var customHistoryEnd: Date? {
        get { defaults.object(forKey: AppSettingsKey.customHistoryEnd) as? Date }
        set { defaults.set(newValue, forKey: AppSettingsKey.customHistoryEnd) }
    }

    static var iCloudSyncEnabled: Bool {
        get {
            migrateLegacyICloudSyncKeyIfNeeded()
            return defaults.bool(forKey: AppSettingsKey.iCloudSyncEnabled)
        }
        set { defaults.set(newValue, forKey: AppSettingsKey.iCloudSyncEnabled) }
    }

    static var lastICloudStatusCheck: Date? {
        get { defaults.object(forKey: AppSettingsKey.lastICloudStatusCheck) as? Date }
        set { defaults.set(newValue, forKey: AppSettingsKey.lastICloudStatusCheck) }
    }

    static var quietHoursStart: Date {
        get {
            defaults.object(forKey: AppSettingsKey.quietHoursStart) as? Date ?? UserProfile.defaultQuietStart
        }
        set { defaults.set(newValue, forKey: AppSettingsKey.quietHoursStart) }
    }

    static var quietHoursEnd: Date {
        get {
            defaults.object(forKey: AppSettingsKey.quietHoursEnd) as? Date ?? UserProfile.defaultQuietEnd
        }
        set { defaults.set(newValue, forKey: AppSettingsKey.quietHoursEnd) }
    }

    static var defaultMoodReminderTime: Date {
        Calendar.current.date(bySettingHour: 20, minute: 0, second: 0, of: Date())
            ?? Date()
    }

    static var moodReminderEnabled: Bool {
        get { defaults.bool(forKey: AppSettingsKey.moodReminderEnabled) }
        set { defaults.set(newValue, forKey: AppSettingsKey.moodReminderEnabled) }
    }

    static var moodReminderTime: Date {
        get {
            let interval = defaults.double(forKey: AppSettingsKey.moodReminderTime)
            guard interval > 0 else { return defaultMoodReminderTime }
            return Date(timeIntervalSince1970: interval)
        }
        set { defaults.set(newValue.timeIntervalSince1970, forKey: AppSettingsKey.moodReminderTime) }
    }

    static let defaultStressAlertThreshold = NotificationPolicy.defaultStressAlertThreshold

    static var stressAlertThreshold: Int {
        get {
            guard defaults.object(forKey: AppSettingsKey.stressAlertThreshold) != nil else {
                return defaultStressAlertThreshold
            }
            return min(max(defaults.integer(forKey: AppSettingsKey.stressAlertThreshold), 0), 100)
        }
        set {
            defaults.set(min(max(newValue, 0), 100), forKey: AppSettingsKey.stressAlertThreshold)
        }
    }

    /// One-time migration from SwiftData profile when the threshold key is missing.
    static func migrateStressAlertThresholdFromProfileIfNeeded(profileThreshold: Int) {
        guard defaults.object(forKey: AppSettingsKey.stressAlertThreshold) == nil else { return }
        stressAlertThreshold = min(max(profileThreshold, 0), 100)
    }

    /// One-time migration from SwiftData profile when quiet-hour keys are missing.
    static func migrateQuietHoursFromProfileIfNeeded(start: Date, end: Date) {
        guard defaults.object(forKey: AppSettingsKey.quietHoursStart) == nil else { return }
        quietHoursStart = start
        quietHoursEnd = end
    }

    static var notificationDailyCount: Int {
        get { defaults.integer(forKey: AppSettingsKey.notificationDailyCount) }
        set { defaults.set(newValue, forKey: AppSettingsKey.notificationDailyCount) }
    }

    /// Start-of-day stamp for resetting the daily notification cap at midnight.
    static var notificationCountResetDay: Date? {
        get { defaults.object(forKey: AppSettingsKey.notificationCountResetDay) as? Date }
        set { defaults.set(newValue, forKey: AppSettingsKey.notificationCountResetDay) }
    }

    static func refreshNotificationDailyCountIfNeeded() {
        let today = Calendar.current.startOfDay(for: Date())
        guard let resetDay = notificationCountResetDay else {
            notificationCountResetDay = today
            notificationDailyCount = 0
            return
        }
        if !Calendar.current.isDate(resetDay, inSameDayAs: today) {
            notificationDailyCount = 0
            notificationCountResetDay = today
        }
    }

    static func recordStressNotificationSent() {
        refreshNotificationDailyCountIfNeeded()
        notificationDailyCount += 1
        lastNotifiedAt = Date()
    }

    #if DEBUG
    /// Clears daily notification cap state so stress alerts can be tested again.
    // CLEANED: resets UserDefaults-backed daily counter, reset day, and legacy notification keys for debug builds
    static func resetNotificationCountForDebug() {
        let keys = [
            "lastNotificationSentAt",
            "notificationCount",
            "notificationCountDate",
            AppSettingsKey.lastNotifiedAt,
            AppSettingsKey.notificationDailyCount,
            AppSettingsKey.notificationCountResetDay
        ]
        for key in keys {
            defaults.removeObject(forKey: key)
        }
        notificationDailyCount = 0
        notificationCountResetDay = nil
        lastNotifiedAt = nil
    }
    #endif

    static var lastBGTaskFallbackAt: Date? {
        get { defaults.object(forKey: AppSettingsKey.lastBGTaskFallbackAt) as? Date }
        set { defaults.set(newValue, forKey: AppSettingsKey.lastBGTaskFallbackAt) }
    }

    static func canRunBGTaskFallback() -> Bool {
        guard let last = lastBGTaskFallbackAt else { return true }
        return Date().timeIntervalSince(last) >= ServiceConstants.bgTaskFallbackMinimumInterval
    }

    static func recordBGTaskFallbackRun() {
        lastBGTaskFallbackAt = Date()
    }
}

// MARK: - Observable store (drives SwiftUI updates for appearance + quiet hours)

@MainActor
@Observable
final class AppSettingsStore {
    static let shared = AppSettingsStore()

    var appearanceMode: AppearanceMode {
        didSet { AppSettings.appearanceMode = appearanceMode }
    }

    var quietHoursStart: Date {
        didSet { AppSettings.quietHoursStart = quietHoursStart }
    }

    var quietHoursEnd: Date {
        didSet { AppSettings.quietHoursEnd = quietHoursEnd }
    }

    var stressAlertThreshold: Int {
        didSet { AppSettings.stressAlertThreshold = stressAlertThreshold }
    }

    private init() {
        appearanceMode = AppSettings.appearanceMode
        quietHoursStart = AppSettings.quietHoursStart
        quietHoursEnd = AppSettings.quietHoursEnd
        stressAlertThreshold = AppSettings.stressAlertThreshold
    }

    func reloadFromStorage() {
        appearanceMode = AppSettings.appearanceMode
        quietHoursStart = AppSettings.quietHoursStart
        quietHoursEnd = AppSettings.quietHoursEnd
        stressAlertThreshold = AppSettings.stressAlertThreshold
    }
}
