//
//  HealthSyncUseCase.swift
//  Stretheo
//

import Foundation

struct HealthSyncUseCase {
    private let healthKit: HealthKitManager

    init(healthKit: HealthKitManager = .shared) {
        self.healthKit = healthKit
    }

    func requestAuthorization() async throws {
        try await healthKit.requestAuthorizationIfNeeded()
    }

    func enableBackgroundMonitoring(
        onNewHealthData: @escaping @Sendable () async -> Void
    ) async throws {
        await healthKit.enableSmartBackgroundMonitoring(onNewData: onNewHealthData)
        BackgroundTaskManager.shared.scheduleNextRefresh()
    }

    func disableBackgroundMonitoring() {
        healthKit.stopBackgroundDelivery()
    }
}
