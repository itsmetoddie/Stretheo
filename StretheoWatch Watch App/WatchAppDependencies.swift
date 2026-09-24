//
//  WatchAppDependencies.swift
//  StretheoWatch
//
//  Lightweight composition root on watchOS for local stress persistence.
//

import Foundation
import OSLog
import WidgetKit

@MainActor
final class AppDependencies {
    static let shared = AppDependencies()

    let stressRepository = WatchLocalStressRepository()

    private init() {}
}

@MainActor
struct WatchLocalStressRepository {
    func save(result: StressResult, input: HealthInput, trigger: TriggerType) throws {
        let snapshot = WatchStressSnapshot(
            stressLevel: result.level,
            stressCategory: result.category.rawValue,
            measuredAt: Date()
        )
        WatchStressStore.save(snapshot)
        WidgetCenter.shared.reloadTimelines(ofKind: StressComplicationWidget.kind)
        StretheoLog.watchHealth.debug("Saved local stress measurement, trigger: \(trigger.rawValue)")
    }
}
