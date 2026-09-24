//
//  HealthKitStoreProvider.swift
//  Stretheo
//
//  Single shared HKHealthStore per target (iOS + watchOS).
//

import HealthKit

enum HealthKitStoreProvider: Sendable {
    nonisolated static let shared: HKHealthStore = HKHealthStore()
}
