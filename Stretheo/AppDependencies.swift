//
//  AppDependencies.swift
//  Stretheo
//
//  Composition root: dual ModelContainers, repositories, use cases, and shared services.
//  CloudKit sync mode is chosen at container creation — restart after toggling iCloud in Settings.
//

import OSLog
import SwiftData
import SwiftUI

@MainActor
final class AppDependencies {
    static private(set) var shared: AppDependencies!

    let userContainer: ModelContainer
    let articleContainer: ModelContainer
    let iCloudSyncEnabledAtLaunch: Bool

    let stressDataActor: StressDataActor
    let historyDataActor: HistoryDataActor
    let stressRepository: SwiftDataStressRepository
    let moodRepository: SwiftDataMoodRepository
    let articleRepository: SwiftDataArticleRepository
    let profileRepository: SwiftDataUserProfileRepository
    let notificationLogRepository: SwiftDataNotificationLogRepository
    let exportLogRepository: SwiftDataExportLogRepository

    let measureStressUseCase: MeasureStressUseCase
    let stressAnalysisHintUseCase: StressAnalysisHintUseCase
    let healthSyncUseCase: HealthSyncUseCase
    let logMoodUseCase: LogMoodUseCase
    let fetchArticlesUseCase: FetchArticlesUseCase
    let exportDataUseCase: ExportDataUseCase

    let exportService: ExportService
    let syncService: SyncService
    let notificationManager: NotificationManager
    let healthKitManager: HealthKitManager

    init(iCloudSyncEnabled: Bool? = nil) {
        let userPrefersCloud = iCloudSyncEnabled ?? ModelContainerFactory.userPrefersICloudSyncFromStorage()
        let cloudEnabled = FeatureFlags.iCloudCapabilityAvailable && userPrefersCloud
        iCloudSyncEnabledAtLaunch = cloudEnabled

        let containers: (user: ModelContainer, articles: ModelContainer)
        do {
            containers = try ModelContainerFactory.makeDualContainers(iCloudSyncEnabled: cloudEnabled)
        } catch {
            StretheoLog.swiftData.error("Primary setup failed: \(error.localizedDescription)")
            StretheoLog.swiftData.notice("Falling back to local-only storage")
            containers = ModelContainerFactory.makeLocalOnlyContainers()
        }
        userContainer = containers.user
        articleContainer = containers.articles

        let userContext = userContainer.mainContext
        let articleContext = articleContainer.mainContext

        stressDataActor = StressDataActor(modelContainer: userContainer)
        historyDataActor = HistoryDataActor(modelContainer: userContainer)
        CloudKitSaveDebouncer.shared.configure(cloudKitEnabled: cloudEnabled)
        stressRepository = SwiftDataStressRepository(
            container: userContainer,
            stressDataActor: stressDataActor
        )
        moodRepository = SwiftDataMoodRepository(
            context: userContext,
            stressDataActor: stressDataActor
        )
        articleRepository = SwiftDataArticleRepository(context: articleContext)
        profileRepository = SwiftDataUserProfileRepository(context: userContext)
        notificationLogRepository = SwiftDataNotificationLogRepository(context: userContext)
        exportLogRepository = SwiftDataExportLogRepository(context: userContext)

        exportService = ExportService()
        syncService = SyncService(profileRepository: profileRepository)
        healthKitManager = .shared
        notificationManager = NotificationManager.shared
        notificationManager.configure(
            notificationLogRepository: notificationLogRepository,
            moodRepository: moodRepository
        )

        measureStressUseCase = MeasureStressUseCase(
            stressRepository: stressRepository,
            profileRepository: profileRepository
        )
        stressAnalysisHintUseCase = StressAnalysisHintUseCase(profileRepository: profileRepository)
        healthSyncUseCase = HealthSyncUseCase()
        logMoodUseCase = LogMoodUseCase(moodRepository: moodRepository)
        fetchArticlesUseCase = FetchArticlesUseCase(articleRepository: articleRepository)
        exportDataUseCase = ExportDataUseCase(
            stressRepository: stressRepository,
            moodRepository: moodRepository,
            exportLogRepository: exportLogRepository,
            exportService: exportService
        )

        AppDependencies.shared = self
    }

    func wipeAllUserData() throws {
        try stressRepository.deleteAll()
        try moodRepository.deleteAll()
        try notificationLogRepository.deleteAll()
        try exportLogRepository.deleteAll()
        try profileRepository.deleteAll()
        try articleRepository.deleteAll()
        _ = try profileRepository.fetchOrCreateProfile()
        WatchConnectivityManager.shared.pushDataWipeToWatch()
    }
}

// MARK: - Environment

private struct AppDependenciesKey: EnvironmentKey {
    static var defaultValue: AppDependencies {
        guard let shared = AppDependencies.shared else {
            fatalError("AppDependencies.shared is not configured. Inject dependencies from StretheoApp.")
        }
        return shared
    }
}

extension EnvironmentValues {
    var appDependencies: AppDependencies {
        get { self[AppDependenciesKey.self] }
        set { self[AppDependenciesKey.self] = newValue }
    }
}
