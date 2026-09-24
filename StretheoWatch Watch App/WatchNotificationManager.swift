//
//  WatchNotificationManager.swift
//  StretheoWatch
//
//  WatchNotificationManager provides a redundant, watchOS-local notification path.
//  This does NOT increase HRV sampling frequency (a HealthKit/watchOS platform
//  constraint) — it removes WatchConnectivity delivery as a single point of failure
//  for the alert itself. Data sync to iPhone for storage/history is unaffected and
//  continues via the existing WatchConnectivity path regardless of this notification path.
//

import Foundation
import OSLog
import UserNotifications

@MainActor
final class WatchNotificationManager {
    static let shared = WatchNotificationManager()

    private let logger = Logger(subsystem: "com.zapreff.Stretheo", category: "WatchNotification")

    private init() {}

    /// Returns whether a local Watch notification was scheduled (for WC payload dedupe).
    func scheduleIfNeeded(result: StressResult, measuredAt: Date) async -> Bool {
        let settings = WatchProfileStore.notificationSettings()

        guard settings.notificationsEnabled else {
            logger.debug("WATCH_GATE_FAIL: notifications disabled")
            return false
        }

        guard result.level >= settings.stressAlertThreshold else {
            logger.debug(
                "WATCH_GATE_FAIL: below threshold (\(result.level, privacy: .private) < \(settings.stressAlertThreshold, privacy: .public))"
            )
            return false
        }

        guard !NotificationPolicy.isWithinQuietHours(
            now: Date(),
            start: settings.quietHoursStart,
            end: settings.quietHoursEnd
        ) else {
            logger.debug("WATCH_GATE_FAIL: within quiet hours")
            return false
        }

        WatchNotificationState.refreshDailyCountIfNeeded()
        let todayCount = WatchNotificationState.notificationDailyCount
        let dailyLimit = NotificationPolicy.maxNotificationsPerDay
        guard todayCount < dailyLimit else {
            logger.debug("WATCH_GATE_FAIL: daily cap reached (\(todayCount, privacy: .public)/\(dailyLimit, privacy: .public))")
            return false
        }

        let minInterval = NotificationPolicy.minimumInterval
        if let last = WatchNotificationState.lastNotifiedAt {
            let elapsed = Date().timeIntervalSince(last)
            guard elapsed >= minInterval else {
                logger.debug(
                    "WATCH_GATE_FAIL: interval not yet elapsed (\(Int(elapsed), privacy: .public)s < \(Int(minInterval), privacy: .public)s)"
                )
                return false
            }
        }

        let consecutiveRequired = NotificationPolicy.consecutiveHighReadingsRequired
        let recentLevels = WatchStressReadingHistory.recentLevels(limit: consecutiveRequired)
        guard NotificationPolicy.consecutiveReadingsMeetThreshold(
            recentLevels: recentLevels,
            threshold: settings.stressAlertThreshold,
            requiredCount: consecutiveRequired
        ) else {
            logger.debug("WATCH_GATE_FAIL: consecutive high readings not yet met")
            return false
        }

        let authorization = await UNUserNotificationCenter.current().notificationSettings()
        let status = authorization.authorizationStatus
        guard status == .authorized || status == .provisional else {
            logger.debug("WATCH_GATE_FAIL: not authorized (\(status.rawValue, privacy: .public))")
            return false
        }

        return await scheduleWatchNotification(category: result.category)
    }

    private func scheduleWatchNotification(category: StressCategory) async -> Bool {
        let content = UNMutableNotificationContent()
        content.title = String(localized: "notification.stress.title")
        content.body = String(localized: "notification.stress.body")
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "watch_stress_alert_\(UUID().uuidString)",
            content: content,
            trigger: nil
        )

        do {
            try await UNUserNotificationCenter.current().add(request)
            WatchNotificationState.recordNotificationSent()
            logger.debug("WATCH_NOTIFICATION_SCHEDULED: success category=\(category.rawValue, privacy: .public)")
            return true
        } catch {
            logger.debug("WATCH_NOTIFICATION_SCHEDULE_ERROR: \(error.localizedDescription, privacy: .public)")
            return false
        }
    }
}
