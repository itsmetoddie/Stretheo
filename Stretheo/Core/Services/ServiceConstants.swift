//
//  ServiceConstants.swift
//  Stretheo
//

import Foundation

/// Shared service identifiers — `nonisolated` so actors and delegates can read them under default MainActor isolation.
enum ServiceConstants {
    nonisolated static let healthSnapshotRetentionDays = 90

    /// Must match `BGTaskSchedulerPermittedIdentifiers` in Config/Stretheo-Info.plist exactly.
    nonisolated static let backgroundTaskID = "com.zapreff.Stretheo.stress.refresh"

    /// BGAppRefreshTask fallback interval (HealthKit observer is primary). iOS may wake later than this hint.
    nonisolated static let backgroundRefreshInterval: TimeInterval = 6 * 60 * 60

    /// Minimum time between any automatic measurements (BGTask + HealthKit).
    nonisolated static let backgroundMeasurementMinimumInterval: TimeInterval = 45 * 60

    /// Skip persisting a new stress reading when one already exists within this window (HK observer bursts).
    nonisolated static let measurementDedupeInterval: TimeInterval = 5 * 60

    /// BGTask fallback may run at most once per 24 hours.
    nonisolated static let bgTaskFallbackMinimumInterval: TimeInterval = 24 * 60 * 60

    nonisolated static let keychainService = "com.zapreff.Stretheo"
    nonisolated static let cloudKitContainerID = "iCloud.com.zapreff.Stretheo"
    nonisolated static let deepLinkBreathing = "stretheo://breathing"
}
