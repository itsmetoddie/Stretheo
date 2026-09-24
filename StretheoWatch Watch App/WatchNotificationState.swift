//
//  WatchNotificationState.swift
//  StretheoWatch
//
//  Per-device notification throttle state (mirrors AppSettings keys on iPhone).
//

import Foundation

enum WatchNotificationState {
    private static let defaults = UserDefaults.standard
    private static let lastNotifiedAtKey = "watch.notification.lastNotifiedAt"
    private static let dailyCountKey = "watch.notification.dailyCount"
    private static let countResetDayKey = "watch.notification.countResetDay"
    private static let hasRequestedAuthKey = "watch.notification.hasRequestedAuthorization"

    static var hasRequestedAuthorization: Bool {
        get { defaults.bool(forKey: hasRequestedAuthKey) }
        set { defaults.set(newValue, forKey: hasRequestedAuthKey) }
    }

    static var lastNotifiedAt: Date? {
        get { defaults.object(forKey: lastNotifiedAtKey) as? Date }
        set { defaults.set(newValue, forKey: lastNotifiedAtKey) }
    }

    static var notificationDailyCount: Int {
        get { defaults.integer(forKey: dailyCountKey) }
        set { defaults.set(newValue, forKey: dailyCountKey) }
    }

    private static var notificationCountResetDay: Date? {
        get { defaults.object(forKey: countResetDayKey) as? Date }
        set { defaults.set(newValue, forKey: countResetDayKey) }
    }

    static func refreshDailyCountIfNeeded() {
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

    static func recordNotificationSent() {
        refreshDailyCountIfNeeded()
        notificationDailyCount += 1
        lastNotifiedAt = Date()
    }

    static func clearAll() {
        defaults.removeObject(forKey: lastNotifiedAtKey)
        defaults.removeObject(forKey: dailyCountKey)
        defaults.removeObject(forKey: countResetDayKey)
    }
}
