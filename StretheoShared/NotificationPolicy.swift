//
//  NotificationPolicy.swift
//  StretheoShared
//
//  Shared stress-alert gate values and quiet-hours logic (iPhone + watchOS).
//

import Foundation

enum NotificationSource: String, Codable, Sendable {
    case iphone
    case watch
}

enum NotificationPolicy {
    #if DEBUG
    nonisolated static let minimumInterval: TimeInterval = 60
    nonisolated static let maxNotificationsPerDay = 20
    #else
    nonisolated static let minimumInterval: TimeInterval = 2 * 60 * 60
    nonisolated static let maxNotificationsPerDay = 3
    #endif

    nonisolated static let consecutiveHighReadingsRequired = 2
    nonisolated static let defaultStressAlertThreshold = 67
    /// Skip iPhone alert when Watch already notified for the same measurement window.
    nonisolated static let watchIPhoneDedupeWindow: TimeInterval = 5 * 60

    nonisolated static func defaultQuietHoursStart(reference: Date = Date()) -> Date {
        Calendar.current.date(from: DateComponents(hour: 22, minute: 0)) ?? reference
    }

    nonisolated static func defaultQuietHoursEnd(reference: Date = Date()) -> Date {
        Calendar.current.date(from: DateComponents(hour: 7, minute: 0)) ?? reference
    }

    nonisolated static func isWithinQuietHours(now: Date, start: Date, end: Date) -> Bool {
        let calendar = Calendar.current
        let nowComponents = calendar.dateComponents([.hour, .minute], from: now)
        let startComponents = calendar.dateComponents([.hour, .minute], from: start)
        let endComponents = calendar.dateComponents([.hour, .minute], from: end)
        guard let nowMinutes = nowComponents.hour.map({ $0 * 60 + (nowComponents.minute ?? 0) }),
              let startMinutes = startComponents.hour.map({ $0 * 60 + (startComponents.minute ?? 0) }),
              let endMinutes = endComponents.hour.map({ $0 * 60 + (endComponents.minute ?? 0) }) else {
            return false
        }
        if startMinutes <= endMinutes {
            return nowMinutes >= startMinutes && nowMinutes < endMinutes
        }
        return nowMinutes >= startMinutes || nowMinutes < endMinutes
    }

    nonisolated static func consecutiveReadingsMeetThreshold(
        recentLevels: [Int],
        threshold: Int,
        requiredCount: Int
    ) -> Bool {
        guard requiredCount > 0 else { return false }
        guard recentLevels.count >= requiredCount else { return false }
        let window = recentLevels.prefix(requiredCount)
        return window.allSatisfy { $0 >= threshold }
    }
}
