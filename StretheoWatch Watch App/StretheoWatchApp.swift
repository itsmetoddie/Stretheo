//
//  StretheoWatchApp.swift
//  StretheoWatch
//

import OSLog
import SwiftData
import SwiftUI
import WatchKit
import WidgetKit

@main
struct StretheoWatchApp: App {
    @WKApplicationDelegateAdaptor(WatchApplicationDelegate.self) private var appDelegate
    @ObservedObject private var watchHealthManager: WatchHealthManager
    @State private var stressModel = WatchStressModel()

    init() {
        let manager = WatchHealthManager.shared
        _watchHealthManager = ObservedObject(wrappedValue: manager)
        WatchConnectivityManager.shared.activate()
        Task { @MainActor in
            StretheoLog.background.info("StretheoWatchApp init — registering monitoring")
            manager.enableBackgroundMonitoring(callSite: "StretheoWatchApp init")
            WatchApplicationDelegate.scheduleNextBackgroundRefresh()
            await WatchNotificationAuthorization.requestIfNeeded()
        }
    }

    var body: some Scene {
        WindowGroup {
            WatchContentView()
                .environment(stressModel)
                .modelContainer(WatchMoodModelContainer.shared)
                .onAppear {
                    WatchConnectivityManager.shared.activate()
                    WatchSessionController.bind(model: stressModel)
                    StretheoLog.background.info("Watch root appeared — initial wake")
                    watchHealthManager.enableBackgroundMonitoring(callSite: "WatchContentView onAppear")
                    WatchApplicationDelegate.scheduleNextBackgroundRefresh()
                }
                .onReceive(NotificationCenter.default.publisher(for: WKApplication.didBecomeActiveNotification)) { _ in
                    StretheoLog.background.info("WKApplication.didBecomeActive — foreground wake")
                    watchHealthManager.enableBackgroundMonitoring(callSite: "WKApplication.didBecomeActive")
                    WatchApplicationDelegate.scheduleNextBackgroundRefresh()
                }
        }
    }
}

// MARK: - Connectivity (iPhone → Watch display)

@MainActor
@Observable
final class WatchStressModel {
    private(set) var snapshot: WatchStressSnapshot

    init() {
        snapshot = WatchStressStore.load()
    }

    var hasData: Bool { snapshot.hasData }

    func apply(context: [String: Any]) {
        guard let updated = WatchStressSnapshot(applicationContext: context) else { return }
        snapshot = updated
        WatchStressStore.save(updated)
        WidgetCenter.shared.reloadTimelines(ofKind: StressComplicationWidget.kind)
    }

    func reloadFromStore() {
        snapshot = WatchStressStore.load()
    }
}

@MainActor
enum WatchSessionController {
    private static weak var stressModel: WatchStressModel?

    static func bind(model: WatchStressModel) {
        stressModel = model
        model.reloadFromStore()
        let context = WCSession.default.receivedApplicationContext
        if !context.isEmpty {
            WatchProfileStore.applyNotificationSettings(from: context)
            if let display = displayContext(from: context) {
                model.apply(context: display)
            }
        }

        WatchConnectivityManager.shared.displayContextHandler = { context in
            stressModel?.apply(context: context)
        }
    }

    private static func displayContext(from context: [String: Any]) -> [String: Any]? {
        guard context[WatchConnectivityPayloadKey.stressLevel.rawValue] as? Int != nil else { return nil }
        return [
            WatchConnectivityPayloadKey.stressLevel.rawValue: context[WatchConnectivityPayloadKey.stressLevel.rawValue] as Any,
            WatchConnectivityPayloadKey.category.rawValue: context[WatchConnectivityPayloadKey.category.rawValue] as Any,
            WatchConnectivityPayloadKey.measuredAt.rawValue: context[WatchConnectivityPayloadKey.measuredAt.rawValue] as Any
        ]
    }
}

import WatchConnectivity
