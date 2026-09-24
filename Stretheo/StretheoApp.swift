//
//  StretheoApp.swift
//  Stretheo
//
//  Entry point: BGTask registration (sync in init), HealthKit observers (primary), BGTask fallback.
//

import OSLog
import SwiftData
import SwiftUI

@main
struct StretheoApp: App {
    @UIApplicationDelegateAdaptor(StretheoAppDelegate.self) private var appDelegate

    private let dependencies: AppDependencies
    @State private var router = AppRouter()
    @State private var appSettings = AppSettingsStore.shared

    init() {
        // NotificationManager.init installs UNUserNotificationCenter delegate — must run first.
        _ = NotificationManager.shared

        let deps = AppDependencies()
        dependencies = deps

        BackgroundTaskManager.shared.configure(dependencies: deps)
        BackgroundStressCoordinator.shared.configure(dependencies: deps)

        WatchConnectivityManager.shared.activate()
    }

    var body: some Scene {
        WindowGroup {
            RootView(dependencies: dependencies, router: router, appSettings: appSettings)
        }
    }
}

// MARK: - Root

private struct RootView: View {
    @Environment(\.scenePhase) private var scenePhase

    let dependencies: AppDependencies
    @Bindable var router: AppRouter
    @Bindable var appSettings: AppSettingsStore

    var body: some View {
        AppRootView()
            .environment(\.appDependencies, dependencies)
            .environment(router)
            .environment(appSettings)
            .modelContainer(dependencies.userContainer)
            .preferredColorScheme(appSettings.appearanceMode.preferredColorScheme)
            .onOpenURL { url in
            if let link = DeepLinkHandler.parse(url: url) {
                router.handle(link)
            }
        }
        .task {
            if router.appState == .launching {
                router.finishLaunch()
            }
            await bootstrap()
        }
            .onChange(of: scenePhase) { _, phase in
                if phase == .background {
                    BackgroundTaskManager.shared.scheduleNextRefresh()
                    StretheoLog.bgTask.debug("[BGTask]")
                } else if phase == .active {
                    DataRetentionService.pruneExpiredHealthSnapshots(repository: dependencies.stressRepository)
                }
            }
            // Cover content for app-switcher / multitasking snapshots (.inactive) and while backgrounded.
            .overlay {
                if scenePhase != .active {
                    AppSwitcherPrivacyOverlay()
                        .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.15), value: scenePhase)
    }

    @MainActor
    private func bootstrap() async {
        AppSettings.migrateHealthKitAuthorizationFlagIfNeeded()
        dependencies.notificationManager.onBreathingAction = { [router] in
            router.openBreathing()
        }
        dependencies.notificationManager.onMoodReminderTap = { [router] in
            router.handle(.mood)
        }
        dependencies.notificationManager.refreshDailyMoodReminderIfNeeded()

        DataRetentionService.pruneExpiredHealthSnapshots(repository: dependencies.stressRepository)
        BackgroundTaskManager.shared.scheduleNextRefresh()
        await configureHealthKitBackgroundMonitoring()
    }

    @MainActor
    private func configureHealthKitBackgroundMonitoring() async {
        guard AppSettings.healthSyncEnabled else { return }
        // iPhone HealthKit observer — backup when Watch is not worn or not paired.
        do {
            try await dependencies.healthSyncUseCase.enableBackgroundMonitoring {
                await BackgroundStressCoordinator.shared.handleNewHealthData()
            }
        } catch {
            StretheoLog.healthKit.error("iPhone background monitoring failed: \(error.localizedDescription)")
        }
    }
}
