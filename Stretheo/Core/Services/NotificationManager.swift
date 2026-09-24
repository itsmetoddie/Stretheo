//
//  NotificationManager.swift
//  Stretheo
//
//  Local stress alerts — threshold-based, rate-limited, quiet-hours aware.
//  Foreground stress alerts: suppressed system UI; bell badge via NotificationLog.
//

import Foundation
import OSLog
import UserNotifications

@MainActor
final class NotificationManager: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationManager()

    nonisolated static let stressCategoryID = "STRESS_ALERT"
    nonisolated static let stressAlertIdentifierPrefix = "stress_alert"
    nonisolated static let breathingActionID = "START_BREATHING"
    nonisolated static let dismissActionID = "DISMISS"
    nonisolated static let dailyMoodReminderID = "daily_mood_reminder"
    nonisolated static let deepLinkKey = "deeplink"
    nonisolated static let deepLinkMoodValue = "mood"
    static let deepLinkBreathing = ServiceConstants.deepLinkBreathing

    private static let deliveryDelay: TimeInterval = 1

    private var notificationLogRepository: NotificationLogRepositoryProtocol?
    private var moodRepository: MoodRepositoryProtocol?
    /// Defaults to the real system center; tests may replace via `configure`.
    private var authorizationChecker: NotificationAuthorizationChecking = SystemNotificationAuthorizationChecker.shared
    var onBreathingAction: (() -> Void)?
    var onMoodReminderTap: (() -> Void)?

    private override init() {
        super.init()
        let center = UNUserNotificationCenter.current()
        center.delegate = self

        if center.delegate == nil {
            StretheoLog.notification.debug("[Notification] ERROR — UNUserNotificationCenter delegate is nil after assignment")
        } else if center.delegate !== self {
            StretheoLog.notification.debug("[Notification] WARNING — delegate is not NotificationManager")
        } else {
            StretheoLog.notification.debug(
                "UNUserNotificationCenter delegate set (\(String(describing: ObjectIdentifier(self))))"
            )
        }

        registerCategories()
    }

    func configure(
        notificationLogRepository: NotificationLogRepositoryProtocol,
        moodRepository: MoodRepositoryProtocol? = nil,
        authorizationChecker: NotificationAuthorizationChecking = SystemNotificationAuthorizationChecker.shared
    ) {
        self.notificationLogRepository = notificationLogRepository
        self.moodRepository = moodRepository
        self.authorizationChecker = authorizationChecker
    }

    func authorizationStatus() async -> UNAuthorizationStatus {
        await authorizationChecker.authorizationStatus()
    }

    func requestAuthorization() async throws -> Bool {
        let granted = try await UNUserNotificationCenter.current().requestAuthorization(
            options: [.alert, .sound, .badge]
        )
        registerCategories()
        return granted
    }

    func registerCategories() {
        let startBreathingAction = UNNotificationAction(
            identifier: Self.breathingActionID,
            title: "Start Breathing Exercise",
            options: [.foreground]
        )
        let dismissAction = UNNotificationAction(
            identifier: Self.dismissActionID,
            title: "Dismiss",
            options: [.destructive]
        )
        let category = UNNotificationCategory(
            identifier: Self.stressCategoryID,
            actions: [startBreathingAction, dismissAction],
            intentIdentifiers: [],
            options: []
        )
        UNUserNotificationCenter.current().setNotificationCategories([category])
        StretheoLog.notification.debug("[Notification] Categories registered — \(Self.stressCategoryID)")
    }

    func scheduleIfNeeded(level: Int) async {
        await scheduleStressAlertIfNeeded(
            level: level,
            category: StressCategory.from(level: level),
            stressRepository: AppDependencies.shared.stressRepository
        )
    }

    #if DEBUG
    /// Resets daily notification cap state for testing the stress alert pipeline.
    func resetDailyCount() {
        AppSettings.resetNotificationCountForDebug()
    }
    #endif

    func scheduleStressAlertIfNeeded(
        level: Int,
        category: StressCategory,
        stressRepository: StressRepositoryProtocol,
        triggeredMeasurement: StressMeasurement? = nil
    ) async {
        let threshold = AppSettings.stressAlertThreshold
        StretheoLog.notification.debug("Evaluating notification gates")

        guard AppSettings.notificationsEnabled else {
            StretheoLog.notification.debug("[Notification] BLOCKED — notifications disabled in Settings")
            return
        }
        StretheoLog.notification.debug("[Notification] Gate 0 passed — notifications enabled")

        if let measurement = triggeredMeasurement,
           (try? notificationLogRepository?.recentlyNotifiedFromWatch(for: measurement.id)) == true {
            StretheoLog.notification.debug("IPHONE_GATE_FAIL: already notified from Watch for this measurement")
            return
        }

        guard level >= threshold else {
            StretheoLog.notification.debug("[Notification] BLOCKED — below stress threshold")
            return
        }
        StretheoLog.notification.debug("[Notification] Gate 1 passed — meets stress threshold")

        if NotificationPolicy.isWithinQuietHours(
            now: Date(),
            start: AppSettings.quietHoursStart,
            end: AppSettings.quietHoursEnd
        ) {
            StretheoLog.notification.debug(
                "BLOCKED — quiet hours active (\(self.quietHoursDescription()))"
            )
            return
        }
        StretheoLog.notification.debug("[Notification] Gate 2 passed — not in quiet hours")

        AppSettings.refreshNotificationDailyCountIfNeeded()
        let todayCount = AppSettings.notificationDailyCount
        let dailyLimit = NotificationPolicy.maxNotificationsPerDay
        if todayCount >= dailyLimit {
            StretheoLog.notification.debug("[Notification] BLOCKED — daily limit reached: \(todayCount)/\(dailyLimit)")
            return
        }
        StretheoLog.notification.debug("[Notification] Gate 3 passed — daily count: \(todayCount)/\(dailyLimit)")

        let minInterval = NotificationPolicy.minimumInterval
        if let last = AppSettings.lastNotifiedAt {
            let elapsed = Date().timeIntervalSince(last)
            if elapsed < minInterval {
                StretheoLog.notification.debug(
                    "BLOCKED — too soon, elapsed: \(Int(elapsed))s, minimum: \(Int(minInterval))s"
                )
                return
            }
            StretheoLog.notification.debug("[Notification] Gate 4 passed — interval ok, elapsed: \(Int(elapsed))s")
        } else {
            StretheoLog.notification.debug("[Notification] Gate 4 passed — no prior notification recorded")
        }

        let status = await authorizationChecker.authorizationStatus()
        guard status == .authorized || status == .provisional else {
            StretheoLog.notification.debug(
                "BLOCKED — not authorized: \(self.authorizationStatusLabel(status))"
            )
            return
        }
        StretheoLog.notification.debug(
            "Gate 5 passed — authorized (\(self.authorizationStatusLabel(status)))"
        )

        let consecutiveRequired = NotificationPolicy.consecutiveHighReadingsRequired
        let recentLevels: [Int]
        do {
            let recent = try stressRepository.recentMeasurements(limit: consecutiveRequired)
            recentLevels = recent.map(\.stressLevel)
        } catch {
            StretheoLog.notification.debug(
                "[Notification] BLOCKED — could not read recent measurements: \(error.localizedDescription)"
            )
            return
        }
        guard NotificationPolicy.consecutiveReadingsMeetThreshold(
            recentLevels: recentLevels,
            threshold: threshold,
            requiredCount: consecutiveRequired
        ) else {
            StretheoLog.notification.debug(
                "[Notification] BLOCKED — need \(consecutiveRequired) consecutive readings at or above threshold; have \(recentLevels.count) recent"
            )
            return
        }
        StretheoLog.notification.debug(
            "Gate 6 passed — consecutive readings meet threshold"
        )

        StretheoLog.notification.debug("[Notification] All gates passed — sending notification")
        await deliverStressNotification(
            level: level,
            category: category,
            threshold: threshold,
            stressRepository: stressRepository,
            triggeredMeasurement: triggeredMeasurement
        )
    }

    private func deliverStressNotification(
        level: Int,
        category: StressCategory,
        threshold: Int,
        stressRepository: StressRepositoryProtocol,
        triggeredMeasurement: StressMeasurement? = nil
    ) async {
        // PRIVACY FIX: lock-screen copy must not expose numeric stress scores or raw biometrics
        let body = String(localized: "notification.stress.body")
        let content = UNMutableNotificationContent()
        content.title = String(localized: "notification.stress.title")
        content.body = body
        content.sound = .default
        content.interruptionLevel = .timeSensitive
        content.categoryIdentifier = Self.stressCategoryID
        // PRIVACY FIX: Notification userInfo no longer contains numeric health values
        content.userInfo = [
            StressNotificationUserInfoKey.category: category.rawValue,
            StressNotificationUserInfoKey.triggered: true
        ]

        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: Self.deliveryDelay,
            repeats: false
        )

        let identifier = "\(Self.stressAlertIdentifierPrefix)_\(UUID().uuidString)"
        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: trigger
        )

        do {
            try await UNUserNotificationCenter.current().add(request)
            AppSettings.recordStressNotificationSent()
            let measurementForLog = triggeredMeasurement ?? (try? stressRepository.latestMeasurement())
            do {
                try notificationLogRepository?.log(
                    stressLevel: level,
                    message: body,
                    triggeredByMeasurement: measurementForLog,
                    source: .iphone
                )
            } catch {
                StretheoLog.notification.error("Notification log save failed: \(error.localizedDescription)")
            }
            let count = AppSettings.notificationDailyCount
            StretheoLog.notification.debug("[Notification] Request added: \(identifier)")
            StretheoLog.notification.debug(
                "Notification scheduled — timeSensitive, fires in \(Int(Self.deliveryDelay))s, daily count \(count)/\(NotificationPolicy.maxNotificationsPerDay)"
            )
        } catch {
            StretheoLog.notification.debug("[Notification] BLOCKED — UNUserNotificationCenter.add failed: \(error.localizedDescription)")
        }
    }

    func removePendingStressNotifications() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }

    func cancelDailyMoodReminder() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: [Self.dailyMoodReminderID]
        )
        StretheoLog.notification.debug("[Notification] Mood reminder cancelled")
    }

    func scheduleDailyMoodReminder(at time: Date = AppSettings.moodReminderTime) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: [Self.dailyMoodReminderID]
        )

        guard AppSettings.moodReminderEnabled else { return }

        let content = UNMutableNotificationContent()
        content.title = String(localized: "notification.mood_reminder.title")
        content.body = String(localized: "notification.mood_reminder.body")
        content.sound = .default
        content.interruptionLevel = .passive
        content.userInfo = [Self.deepLinkKey: Self.deepLinkMoodValue]

        let components = Calendar.current.dateComponents([.hour, .minute], from: time)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        let request = UNNotificationRequest(
            identifier: Self.dailyMoodReminderID,
            content: content,
            trigger: trigger
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error {
                StretheoLog.notification.debug("[Notification] Mood reminder failed: \(error)")
            } else {
                let hour = components.hour ?? 0
                let minute = components.minute ?? 0
                StretheoLog.notification.debug(
                    "Mood reminder scheduled at \(hour):\(String(format: "%02d", minute))"
                )
            }
        }
    }

    func refreshDailyMoodReminderIfNeeded() {
        if AppSettings.moodReminderEnabled {
            scheduleDailyMoodReminder(at: AppSettings.moodReminderTime)
        } else {
            cancelDailyMoodReminder()
        }
    }

    private func checkIfMoodLoggedToday() -> Bool {
        guard let moodRepository else { return false }
        guard let entries = try? moodRepository.todayEntries() else { return false }
        return !entries.isEmpty
    }

    private func quietHoursDescription() -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return "\(formatter.string(from: AppSettings.quietHoursStart))–\(formatter.string(from: AppSettings.quietHoursEnd))"
    }

    private func authorizationStatusLabel(_ status: UNAuthorizationStatus) -> String {
        switch status {
        case .notDetermined: "notDetermined"
        case .denied: "denied"
        case .authorized: "authorized"
        case .provisional: "provisional"
        case .ephemeral: "ephemeral"
        @unknown default: "unknown(\(status.rawValue))"
        }
    }

    // MARK: - UNUserNotificationCenterDelegate

    /// Foreground: suppress stress alert UI; NotificationLog + bell badge handle in-app awareness.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        let identifier = notification.request.identifier
        let categoryID = notification.request.content.categoryIdentifier
        StretheoLog.notification.debug("[Notification] willPresent — category: \(categoryID), id: \(identifier)")

        if identifier == Self.dailyMoodReminderID {
            let hasMoodToday = await MainActor.run {
                NotificationManager.shared.checkIfMoodLoggedToday()
            }
            if hasMoodToday {
                StretheoLog.notification.debug("[Notification] Mood reminder suppressed — mood already logged today")
                return []
            }
            return [.banner, .sound, .badge]
        }

        if Self.sharedIsStressAlertNotification(notification) {
            StretheoLog.notification.debug("[Notification] Foreground stress alert suppressed — bell badge handles it")
            return []
        }

        return [.banner, .sound, .badge]
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        StretheoLog.notification.debug("[Notification] didReceive — action: \(response.actionIdentifier)")

        let userInfo = response.notification.request.content.userInfo
        if userInfo[Self.deepLinkKey] as? String == Self.deepLinkMoodValue {
            await MainActor.run {
                NotificationManager.shared.onMoodReminderTap?()
            }
            return
        }

        switch response.actionIdentifier {
        case Self.breathingActionID:
            await MainActor.run {
                NotificationManager.shared.onBreathingAction?()
            }
        case Self.dismissActionID, UNNotificationDismissActionIdentifier:
            break
        case UNNotificationDefaultActionIdentifier:
            // Body tap on a stress alert → same destination as the "Start Breathing" action.
            // AppRouter.handleNotificationUserInfo is mood-deeplink-only and does not match
            // stress alert userInfo (category/triggered, no deeplink key) — do not force it here.
            if Self.sharedIsStressAlertNotification(response.notification) {
                await MainActor.run {
                    NotificationManager.shared.onBreathingAction?()
                }
            }
        default:
            break
        }
    }

    private nonisolated static func sharedIsStressAlertNotification(_ notification: UNNotification) -> Bool {
        let identifier = notification.request.identifier
        if identifier.contains(stressAlertIdentifierPrefix) {
            return true
        }
        return notification.request.content.categoryIdentifier == stressCategoryID
    }

    private nonisolated static func stressCategory(from userInfo: [AnyHashable: Any]) -> StressCategory {
        if let raw = userInfo[StressNotificationUserInfoKey.category] as? String,
           let category = StressCategory(rawValue: raw) {
            return category
        }
        if let raw = userInfo["category"] as? String,
           let category = StressCategory(rawValue: raw) {
            return category
        }
        if let level = userInfo[StressNotificationUserInfoKey.level] as? Int {
            return StressCategory.from(level: level)
        }
        if let level = userInfo[StressNotificationUserInfoKey.level] as? NSNumber {
            return StressCategory.from(level: level.intValue)
        }
        if let level = userInfo["stressLevel"] as? Int {
            return StressCategory.from(level: level)
        }
        if let level = userInfo["stressLevel"] as? NSNumber {
            return StressCategory.from(level: level.intValue)
        }
        return .high
    }
}
