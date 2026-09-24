//
//  Notification+Stress.swift
//  Stretheo
//

import Foundation

extension Notification.Name {
    /// Posted after a new stress measurement is persisted (manual or background).
    static let newMeasurementSaved = Notification.Name("stretheo.newMeasurementSaved")
    /// Scroll History to the Check-ins section (e.g. from Home "See All").
    static let scrollToCheckIns = Notification.Name("stretheo.scrollToCheckIns")
}

enum StressNotificationUserInfoKey: Sendable {
    /// In-app stress alert routing (no numeric health values).
    nonisolated static let category = "category"
    nonisolated static let triggered = "triggered"
    /// Gauge refresh after a new measurement is saved (in-app only).
    nonisolated static let level = "level"
}
