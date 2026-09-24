//
//  WatchApplicationDelegate.swift
//  StretheoWatch
//

import OSLog
import WatchKit

private let logger = Logger(subsystem: "com.zapreff.Stretheo", category: "BackgroundMonitoring")

final class WatchApplicationDelegate: NSObject, WKApplicationDelegate {
    func applicationDidFinishLaunching() {
        logger.info("App finished launching — registering monitoring")
        performBackgroundMonitoringWake(callSite: "applicationDidFinishLaunching")
    }

    func applicationDidBecomeActive() {
        logger.info("App became active — re-registering monitoring")
        performBackgroundMonitoringWake(callSite: "applicationDidBecomeActive")
    }

    func handle(_ backgroundTasks: Set<WKRefreshBackgroundTask>) {
        for task in backgroundTasks {
            switch task {
            case let refreshTask as WKApplicationRefreshBackgroundTask:
                logger.info("WKApplicationRefreshBackgroundTask fired at \(Date(), privacy: .public)")

                /// Shared progress label for expiration logging (handler may run off the main actor).
                final class RefreshStep: @unchecked Sendable {
                    private let lock = NSLock()
                    private var value = "starting"
                    var current: String {
                        lock.lock()
                        defer { lock.unlock() }
                        return value
                    }
                    func set(_ step: String) {
                        lock.lock()
                        value = step
                        lock.unlock()
                    }
                }

                /// Ensures `setTaskCompletedWithSnapshot` + reschedule run exactly once.
                final class CompletionGate: @unchecked Sendable {
                    private let lock = NSLock()
                    private var didComplete = false
                    func completeOnce(_ body: () -> Void) {
                        lock.lock()
                        defer { lock.unlock() }
                        guard !didComplete else { return }
                        didComplete = true
                        body()
                    }
                }

                final class WorkBox: @unchecked Sendable {
                    var task: Task<Void, Never>?
                }

                let step = RefreshStep()
                let gate = CompletionGate()
                let workBox = WorkBox()

                // Set before starting work — required so mid-await suspension still completes the task.
                refreshTask.expirationHandler = {
                    let interruptedAt = step.current
                    workBox.task?.cancel()
                    logger.warning(
                        "WKApplicationRefreshBackgroundTask expired before completing — interruptedAt=\(interruptedAt, privacy: .public); cancelling in-flight work"
                    )
                    gate.completeOnce {
                        Self.scheduleNextBackgroundRefresh()
                        refreshTask.setTaskCompletedWithSnapshot(false)
                    }
                }

                workBox.task = Task { @MainActor in
                    defer {
                        gate.completeOnce {
                            Self.scheduleNextBackgroundRefresh()
                            refreshTask.setTaskCompletedWithSnapshot(false)
                            logger.info("WKApplicationRefreshBackgroundTask completed")
                        }
                    }
                    do {
                        step.set("activate")
                        WatchConnectivityManager.shared.activate()
                        try Task.checkCancellation()

                        step.set("enableBackgroundMonitoring")
                        WatchHealthManager.shared.enableBackgroundMonitoring(callSite: "WKApplicationRefreshBackgroundTask")
                        try Task.checkCancellation()

                        step.set("performMeasurementIfNeeded")
                        await WatchHealthManager.shared.performMeasurementIfNeeded()
                        try Task.checkCancellation()

                        step.set("logHRVObserverQuietPeriod")
                        WatchHealthManager.shared.logHRVObserverQuietPeriodIfNeeded()
                        step.set("finished")
                    } catch is CancellationError {
                        logger.info(
                            "WKApplicationRefreshBackgroundTask work cancelled after expiration — interruptedAt=\(step.current, privacy: .public)"
                        )
                    } catch {
                        logger.error(
                            "WKApplicationRefreshBackgroundTask work failed: \(error.localizedDescription, privacy: .public)"
                        )
                    }
                }

            case let snapshotTask as WKSnapshotRefreshBackgroundTask:
                snapshotTask.setTaskCompleted(
                    restoredDefaultState: true,
                    estimatedSnapshotExpiration: Date.distantFuture,
                    userInfo: nil
                )

            default:
                task.setTaskCompletedWithSnapshot(false)
            }
        }
    }

    private func performBackgroundMonitoringWake(callSite: String) {
        runOnMainActor {
            WatchConnectivityManager.shared.activate()
            WatchHealthManager.shared.enableBackgroundMonitoring(callSite: callSite)
            WatchHealthManager.shared.logHRVObserverQuietPeriodIfNeeded()
            Self.scheduleNextBackgroundRefresh()
        }
    }

    private func runOnMainActor(_ work: @MainActor () -> Void) {
        if Thread.isMainThread {
            MainActor.assumeIsolated { work() }
        } else {
            DispatchQueue.main.sync {
                MainActor.assumeIsolated { work() }
            }
        }
    }

    static func scheduleNextBackgroundRefresh() {
        let nextDate = Date().addingTimeInterval(15 * 60)
        logger.info("Next background refresh scheduled for \(nextDate.formatted(), privacy: .public)")
        WKApplication.shared().scheduleBackgroundRefresh(
            withPreferredDate: nextDate,
            userInfo: nil
        ) { error in
            if let error {
                logger.error("Failed to schedule refresh: \(error.localizedDescription, privacy: .public)")
            }
        }
    }
}
