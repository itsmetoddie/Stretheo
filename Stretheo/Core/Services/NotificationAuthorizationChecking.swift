//
//  NotificationAuthorizationChecking.swift
//  Stretheo
//
//  Minimal seam for Gate 5 authorization status — injectable in tests.
//

import Foundation
import UserNotifications

@MainActor
protocol NotificationAuthorizationChecking: AnyObject {
    func authorizationStatus() async -> UNAuthorizationStatus
}

/// Production checker — always reads `UNUserNotificationCenter.current()`.
@MainActor
final class SystemNotificationAuthorizationChecker: NotificationAuthorizationChecking {
    static let shared = SystemNotificationAuthorizationChecker()

    func authorizationStatus() async -> UNAuthorizationStatus {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        return settings.authorizationStatus
    }
}
