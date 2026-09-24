//
//  ModelContainerFactory.swift
//  Stretheo
//
//  Dual ModelContainer setup:
//  - UserData: stress, mood, profile, logs (optional CloudKit private sync at launch)
//  - Articles: cached editorial content (local only — CloudKit Public DB via CKRecord)
//
//  Uses SwiftData automatic lightweight migration (no custom SchemaMigrationPlan).
//  Store files are only deleted as a last resort after open retry fails.
//

import Foundation
import OSLog
import SwiftData

// MARK: - Factory

enum ModelContainerFactory {
    /// Reads persisted iCloud preference before creating any `ModelContainer`.
    static func userPrefersICloudSyncFromStorage() -> Bool {
        AppSettings.migrateLegacyICloudSyncKeyIfNeeded()
        return UserDefaults.standard.bool(forKey: AppSettingsKey.iCloudSyncEnabled)
    }

    /// Prefer keeping data: run migration plan, retry open once, delete store only if allowed.
    enum StoreOpenPolicy {
        case preserveData
        case allowDestructiveRecovery
    }

    enum UserContainerMode: String {
        case cloudKit = "CloudKit (.automatic)"
        case local = "local-only (.none)"
        case inMemory = "in-memory fallback"
    }

    enum ArticleContainerMode: String {
        case local = "local-only (.none)"
        case inMemory = "in-memory fallback"
    }

    enum ModelContainerError: Error {
        case primarySetupFailed(underlying: Error?)
    }

    static func cloudKitDatabase(iCloudSyncEnabled: Bool) -> ModelConfiguration.CloudKitDatabase {
        guard FeatureFlags.iCloudCapabilityAvailable, iCloudSyncEnabled else { return .none }
        return .automatic
    }

    /// Primary setup — migration-first; logs failures and retries before any store deletion.
    static func makeDualContainers(iCloudSyncEnabled: Bool) throws -> (user: ModelContainer, articles: ModelContainer) {
        do {
            return try openDualContainers(iCloudSyncEnabled: iCloudSyncEnabled, policy: .preserveData)
        } catch {
            StretheoLog.swiftData.error("Primary setup failed: \(error.localizedDescription)")
            StretheoLog.swiftData.notice("Retrying with migration recovery before considering store reset")
            do {
                return try openDualContainers(
                    iCloudSyncEnabled: iCloudSyncEnabled,
                    policy: .allowDestructiveRecovery
                )
            } catch let recoveryError {
                StretheoLog.swiftData.error("Migration recovery failed: \(recoveryError.localizedDescription)")
                throw ModelContainerError.primarySetupFailed(underlying: recoveryError)
            }
        }
    }

    private static func openDualContainers(
        iCloudSyncEnabled: Bool,
        policy: StoreOpenPolicy
    ) throws -> (user: ModelContainer, articles: ModelContainer) {
        let articles = try makeArticleContainer(policy: policy)
        guard let user = makePersistedUserContainer(iCloudSyncEnabled: iCloudSyncEnabled, policy: policy) else {
            throw ModelContainerError.primarySetupFailed(underlying: nil)
        }
        StretheoLog.swiftData.notice("Ready — UserData: persisted, Articles: \(articles.mode.rawValue)")
        return (user, articles.container)
    }

    /// Local-only fallback — migration-first, destructive recovery only when needed.
    static func makeLocalOnlyContainers() -> (user: ModelContainer, articles: ModelContainer) {
        let articles: (container: ModelContainer, mode: ArticleContainerMode)
        do {
            articles = try makeArticleContainer(policy: .preserveData)
        } catch {
            StretheoLog.swiftData.error("Articles fallback — migration failed: \(error.localizedDescription)")
            if let recovered = try? makeArticleContainer(policy: .allowDestructiveRecovery) {
                articles = recovered
            } else {
                StretheoLog.swiftData.notice("Articles fallback — using in-memory store")
                articles = (createInMemoryArticleContainer(), .inMemory)
            }
        }

        if let user = makePersistedUserContainer(iCloudSyncEnabled: false, policy: .preserveData) {
            StretheoLog.swiftData.notice("Fallback — UserData: local-only (.none), Articles: \(articles.mode.rawValue)")
            return (user, articles.container)
        }

        StretheoLog.swiftData.notice("UserData fallback — retrying with destructive recovery")
        if let user = makePersistedUserContainer(iCloudSyncEnabled: false, policy: .allowDestructiveRecovery) {
            StretheoLog.swiftData.notice("Fallback — UserData: local-only (.none), Articles: \(articles.mode.rawValue)")
            return (user, articles.container)
        }

        StretheoLog.swiftData.notice("Fallback — using in-memory UserData + \(articles.mode.rawValue) Articles")
        return (createInMemoryUserContainer(), articles.container)
    }

    // MARK: - User container

    private static func makePersistedUserContainer(
        iCloudSyncEnabled: Bool,
        policy: StoreOpenPolicy
    ) -> ModelContainer? {
        let wantsCloudKit = FeatureFlags.iCloudCapabilityAvailable && iCloudSyncEnabled

        if wantsCloudKit {
            do {
                let container = try createUserContainer(
                    cloudKitDatabase: .automatic,
                    policy: policy,
                    cloudKitModeLabel: "CloudKit (.automatic)"
                )
                StretheoLog.swiftData.info("UserData created with CloudKit (.automatic)")
                return container
            } catch {
                StretheoLog.swiftData.error("CloudKit user container failed: \(error.localizedDescription)")
                StretheoLog.swiftData.notice("Attempting local-only path with automatic migration")
            }
        }

        do {
            let container = try createUserContainer(
                cloudKitDatabase: .none,
                policy: policy,
                cloudKitModeLabel: "local-only (.none)"
            )
            StretheoLog.swiftData.info("UserData created with local-only (.none)")
            return container
        } catch {
            StretheoLog.swiftData.error("Persisted user container unavailable: \(error.localizedDescription)")
            return nil
        }
    }

    private static func userConfiguration(
        cloudKitDatabase: ModelConfiguration.CloudKitDatabase
    ) -> ModelConfiguration {
        // PRIVACY FIX: SwiftData persists under Application Support (not user-visible Documents) with system file protection.
        ModelConfiguration(
            "UserData",
            schema: SwiftDataSchema.userSchema,
            cloudKitDatabase: cloudKitDatabase
        )
    }

    private static func createUserContainer(
        cloudKitDatabase: ModelConfiguration.CloudKitDatabase,
        policy: StoreOpenPolicy,
        cloudKitModeLabel: String
    ) throws -> ModelContainer {
        try openPersistedStore(
            label: "UserData (\(cloudKitModeLabel))",
            schema: SwiftDataSchema.userSchema,
            configuration: userConfiguration(cloudKitDatabase: cloudKitDatabase),
            policy: policy
        )
    }

    private static func createInMemoryUserContainer() -> ModelContainer {
        let configuration = ModelConfiguration(
            "UserData",
            schema: SwiftDataSchema.userSchema,
            isStoredInMemoryOnly: true,
            cloudKitDatabase: .none
        )

        if let container = try? ModelContainer(
            for: SwiftDataSchema.userSchema,
            configurations: configuration
        ) {
            return container
        }

        StretheoLog.swiftData.error("In-memory UserData failed; using profile-only emergency container")
        return emergencyUserContainer()
    }

    private static func emergencyUserContainer() -> ModelContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        if let container = try? ModelContainer(for: UserProfile.self, configurations: config) {
            return container
        }
        if let container = try? ModelContainer(
            for: SwiftDataSchema.userSchema,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        ) {
            return container
        }
        preconditionFailure("[ModelContainer] Unable to create emergency in-memory UserData container")
    }

    // MARK: - Article container (always local)

    private static func makeArticleContainer(
        policy: StoreOpenPolicy
    ) throws -> (container: ModelContainer, mode: ArticleContainerMode) {
        do {
            let container = try createArticleContainer(policy: policy)
            StretheoLog.swiftData.info("Articles created with local-only (.none)")
            return (container, .local)
        } catch {
            StretheoLog.swiftData.error("Articles container failed: \(error.localizedDescription)")
            throw error
        }
    }

    private static func articleConfiguration() -> ModelConfiguration {
        ModelConfiguration(
            "Articles",
            schema: SwiftDataSchema.articleSchema,
            cloudKitDatabase: .none
        )
    }

    private static func createArticleContainer(policy: StoreOpenPolicy) throws -> ModelContainer {
        try openPersistedStore(
            label: "Articles",
            schema: SwiftDataSchema.articleSchema,
            configuration: articleConfiguration(),
            policy: policy
        )
    }

    private static func createInMemoryArticleContainer() -> ModelContainer {
        let configuration = ModelConfiguration(
            "Articles",
            schema: SwiftDataSchema.articleSchema,
            isStoredInMemoryOnly: true,
            cloudKitDatabase: .none
        )

        if let container = try? ModelContainer(
            for: SwiftDataSchema.articleSchema,
            configurations: configuration
        ) {
            return container
        }

        StretheoLog.swiftData.error("In-memory Articles failed; using article-only emergency container")
        return emergencyArticleContainer()
    }

    private static func emergencyArticleContainer() -> ModelContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        if let container = try? ModelContainer(for: Article.self, configurations: config) {
            return container
        }
        if let container = try? ModelContainer(
            for: SwiftDataSchema.articleSchema,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        ) {
            return container
        }
        preconditionFailure("[ModelContainer] Unable to create emergency in-memory Articles container")
    }

    // MARK: - Store open (automatic lightweight migration)

    /// Opens a persisted store with SwiftData automatic migration; retries once before optional reset.
    private static func openPersistedStore(
        label: String,
        schema: Schema,
        configuration: ModelConfiguration,
        policy: StoreOpenPolicy
    ) throws -> ModelContainer {
        do {
            let container = try ModelContainer(for: schema, configurations: configuration)
            if configuration.name == "UserData" {
                applySwiftDataStoreFileProtection(container: container, configuration: configuration)
            }
            return container
        } catch let firstError {
            StretheoLog.swiftData.error("\(label) open failed: \(firstError.localizedDescription)")
            StretheoLog.swiftData.notice("\(label) re-attempting open with automatic migration")

            do {
                let container = try ModelContainer(for: schema, configurations: configuration)
                StretheoLog.swiftData.info("\(label) opened successfully after retry")
                if configuration.name == "UserData" {
                    applySwiftDataStoreFileProtection(container: container, configuration: configuration)
                }
                return container
            } catch let retryError {
                StretheoLog.swiftData.error("\(label) retry failed: \(retryError.localizedDescription)")

                switch policy {
                case .preserveData:
                    throw retryError
                case .allowDestructiveRecovery:
                    StretheoLog.swiftData.notice("\(label) last resort — deleting store and recreating")
                    deleteStoreFiles(for: configuration)
                    let container = try ModelContainer(for: schema, configurations: configuration)
                    if configuration.name == "UserData" {
                        applySwiftDataStoreFileProtection(container: container, configuration: configuration)
                    }
                    return container
                }
            }
        }
    }

    private static func applySwiftDataStoreFileProtection(
        container: ModelContainer,
        configuration: ModelConfiguration
    ) {
        let storeURL = container.configurations.first?.url ?? configuration.url
        for url in storeFileURLs(for: storeURL) {
            try? (url as NSURL).setResourceValue(
                URLFileProtection.completeUnlessOpen,
                forKey: .fileProtectionKey
            )
        }
        // PRIVACY FIX: Explicit NSFileProtectionCompleteUnlessOpen on SwiftData store
    }

    // MARK: - Store reset

    private static func deleteStoreFiles(for configuration: ModelConfiguration) {
        let urls = storeFileURLs(for: configuration.url)
        let fileManager = FileManager.default
        for url in urls {
            guard fileManager.fileExists(atPath: url.path) else { continue }
            do {
                try fileManager.removeItem(at: url)
                StretheoLog.swiftData.info("Removed store file: \(url.lastPathComponent)")
            } catch {
                StretheoLog.swiftData.error("Failed to remove \(url.path): \(error.localizedDescription)")
            }
        }
    }

    private static func storeFileURLs(for storeURL: URL) -> [URL] {
        let base = storeURL.path
        return [
            storeURL,
            URL(fileURLWithPath: base + "-shm"),
            URL(fileURLWithPath: base + "-wal")
        ]
    }
}
