//
//  StretheoAppDelegate.swift
//  Stretheo
//
//  BGTaskScheduler registration runs once per process in didFinishLaunching only.
//

import BackgroundTasks
import OSLog
import UIKit

final class StretheoAppDelegate: NSObject, UIApplicationDelegate {
    private static var didRegisterBackgroundTasks = false
    private static let registrationLock = NSLock()

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        registerBackgroundTasksIfNeeded()
        return true
    }

    private func registerBackgroundTasksIfNeeded() {
        Self.registrationLock.lock()
        defer { Self.registrationLock.unlock() }
        guard !Self.didRegisterBackgroundTasks else {
            StretheoLog.bgTask.debug("BGTask registration skipped — already registered")
            return
        }

        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: ServiceConstants.backgroundTaskID,
            using: nil
        ) { task in
            guard let refreshTask = task as? BGAppRefreshTask else {
                task.setTaskCompleted(success: false)
                return
            }
            Task { @MainActor in
                await BackgroundTaskManager.shared.handleRefresh(task: refreshTask)
            }
        }

        Self.didRegisterBackgroundTasks = true
        StretheoLog.bgTask.info("Registered successfully (\(ServiceConstants.backgroundTaskID))")

        BackgroundTaskManager.shared.scheduleNextRefresh()
    }
}
