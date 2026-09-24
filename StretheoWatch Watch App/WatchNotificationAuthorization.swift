//
//  WatchNotificationAuthorization.swift
//  StretheoWatch
//

import OSLog
import UserNotifications

private let authLogger = Logger(subsystem: "com.zapreff.Stretheo", category: "WatchNotification")

enum WatchNotificationAuthorization {
    static func requestIfNeeded() async {
        guard !WatchNotificationState.hasRequestedAuthorization else { return }
        WatchNotificationState.hasRequestedAuthorization = true
        await requestWatchNotificationAuthorization()
    }

    static func requestWatchNotificationAuthorization() async {
        let center = UNUserNotificationCenter.current()
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound])
            authLogger.debug("WATCH_NOTIFICATION_AUTH: granted=\(granted, privacy: .public)")
        } catch {
            authLogger.debug("WATCH_NOTIFICATION_AUTH_ERROR: \(error.localizedDescription, privacy: .public)")
        }
    }
}
