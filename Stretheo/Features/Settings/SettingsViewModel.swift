//
//  SettingsViewModel.swift
//  Stretheo
//

import AuthenticationServices
import Foundation
import SwiftUI
import UIKit

enum ICloudSyncDisplayStatus: Equatable {
    case localOnly
    case syncing
    case lastSynced(Date)
    case restartRequired
    case unavailable

    var iconName: String {
        switch self {
        case .localOnly: "icloud.slash"
        case .syncing: "icloud.fill"
        case .lastSynced: "icloud.fill"
        case .restartRequired: "icloud.fill"
        case .unavailable: "icloud.slash.fill"
        }
    }

    var iconColor: Color {
        switch self {
        case .localOnly: Color(uiColor: .systemGray)
        case .syncing, .lastSynced: Color(uiColor: .systemGreen)
        case .restartRequired: Color(uiColor: .systemOrange)
        case .unavailable: Color(uiColor: .systemRed)
        }
    }

    func message(lastChecked: Date?) -> String {
        switch self {
        case .localOnly:
            String(localized: "icloud.status.local_only")
        case .syncing:
            String(localized: "icloud.status.syncing")
        case .lastSynced(let date):
            String(
                format: String(localized: "icloud.status.last_synced"),
                date.formatted(date: .abbreviated, time: .shortened)
            )
        case .restartRequired:
            String(localized: "icloud.sync.restart_banner")
        case .unavailable:
            String(localized: "icloud.status.unavailable")
        }
    }
}

@MainActor
@Observable
final class SettingsViewModel {
    private let dependencies: AppDependencies

    var profile: UserProfile?
    /// Bumped when avatar storage is cleared so views can drop cached images.
    var avatarCacheRevision = 0
    private var avatarDidLoad = false
    private var cachedAvatarImage: UIImage?
    var iCloudSyncDisplay: ICloudSyncDisplayStatus = .localOnly
    var iCloudStatus = ""
    var isSignedIn = false
    var errorMessage: String?
    var showError = false
    var showClearDataAlert = false
    var showDeleteAccountAlert = false
    var exportURL: URL?
    var showExportSheet = false

    init(dependencies: AppDependencies) {
        self.dependencies = dependencies
    }

    /// Loads the profile photo from disk once per session; safe to call from view `onAppear`.
    func ensureAvatarLoaded(displayPointSize: CGFloat = 72) -> UIImage? {
        if let cachedAvatarImage { return cachedAvatarImage }
        guard !avatarDidLoad else { return nil }
        avatarDidLoad = true
        if let loaded = ProfileStore.shared.loadAvatarImage() {
            let display = loaded.downsampledForDisplay(pointSize: displayPointSize)
            cachedAvatarImage = display
            return display
        }
        return nil
    }

    func updateAvatarImage(_ image: UIImage) {
        cachedAvatarImage = image
        avatarDidLoad = true
    }

    private func invalidateAvatarCache() {
        cachedAvatarImage = nil
        avatarDidLoad = false
        avatarCacheRevision += 1
    }

    func reload() async {
        do {
            profile = try dependencies.profileRepository.fetchOrCreateProfile()

            if let profile {
                AppSettings.migrateQuietHoursFromProfileIfNeeded(
                    start: profile.quietHoursStart,
                    end: profile.quietHoursEnd
                )
                AppSettings.migrateStressAlertThresholdFromProfileIfNeeded(
                    profileThreshold: profile.notifThreshold
                )
                profile.quietHoursStart = AppSettings.quietHoursStart
                profile.quietHoursEnd = AppSettings.quietHoursEnd
                profile.notifThreshold = AppSettings.stressAlertThreshold
                profile.iCloudSyncEnabled = AppSettings.iCloudSyncEnabled
                try? dependencies.profileRepository.save()
            }
            AppSettingsStore.shared.reloadFromStorage()
            if FeatureFlags.signInWithAppleEnabled {
                isSignedIn = await KeychainManager.shared.appleUserIdentifier() != nil
            } else {
                isSignedIn = false
            }
            await refreshICloudSyncDisplay(userEnabled: AppSettings.iCloudSyncEnabled)
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }

    func refreshICloudSyncDisplay(userEnabled: Bool) async {
        guard FeatureFlags.iCloudCapabilityAvailable else {
            iCloudSyncDisplay = .localOnly
            iCloudStatus = ""
            return
        }

        if !userEnabled {
            iCloudSyncDisplay = .localOnly
            iCloudStatus = iCloudSyncDisplay.message(lastChecked: nil)
            return
        }

        if userEnabled != dependencies.iCloudSyncEnabledAtLaunch {
            iCloudSyncDisplay = .restartRequired
            iCloudStatus = iCloudSyncDisplay.message(lastChecked: nil)
            return
        }

        let account = await dependencies.syncService.accountStatus()
        switch account.status {
        case .available:
            if let last = AppSettings.lastICloudStatusCheck {
                iCloudSyncDisplay = .lastSynced(last)
            } else {
                iCloudSyncDisplay = .syncing
            }
        case .featureDisabled:
            iCloudSyncDisplay = .localOnly
        default:
            iCloudSyncDisplay = .unavailable
        }
        iCloudStatus = iCloudSyncDisplay.message(lastChecked: AppSettings.lastICloudStatusCheck)
    }

    func validateICloudAccountBeforeEnable() async throws {
        guard FeatureFlags.iCloudCapabilityAvailable else {
            throw AppError.cloudKitUnavailable
        }
        let account = await dependencies.syncService.accountStatus()
        guard account.status == .available else {
            throw AppError.cloudKitUnavailable
        }
    }

    func syncProfileICloudPreference(_ enabled: Bool) async {
        guard FeatureFlags.iCloudCapabilityAvailable else { return }
        do {
            try await dependencies.syncService.setICloudSyncEnabled(enabled)
            profile?.iCloudSyncEnabled = enabled
            await refreshICloudSyncDisplay(userEnabled: enabled)
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }

    func toggleHealthSync(_ enabled: Bool) async {
        AppSettings.healthSyncEnabled = enabled

        if enabled {
            do {
                try await dependencies.healthSyncUseCase.enableBackgroundMonitoring {
                    await BackgroundStressCoordinator.shared.handleNewHealthData()
                }
            } catch {
                AppSettings.healthSyncEnabled = false
                errorMessage = error.localizedDescription
                showError = true
            }
        } else {
            dependencies.healthSyncUseCase.disableBackgroundMonitoring()
        }
    }

    func syncQuietHoursToProfile() {
        profile?.quietHoursStart = AppSettings.quietHoursStart
        profile?.quietHoursEnd = AppSettings.quietHoursEnd
        saveProfile()
        WatchConnectivityManager.shared.pushNotificationSettingsToWatch()
    }

    func toggleNotifications(_ enabled: Bool) async {
        AppSettings.notificationsEnabled = enabled
        WatchConnectivityManager.shared.pushNotificationSettingsToWatch()
        if enabled {
            dependencies.notificationManager.registerCategories()
            do {
                _ = try await dependencies.notificationManager.requestAuthorization()
            } catch {
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }

    func saveProfile() {
        do {
            try dependencies.profileRepository.save()
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }

    func signInWithApple() {
        guard FeatureFlags.signInWithAppleEnabled else { return }
        Task {
            do {
                try await AuthManager.shared.signInWithApple()
                await applySignedInProfileFromApple()
            } catch {
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }

    func processAppleSignIn(_ result: Result<ASAuthorization, Error>) {
        guard FeatureFlags.signInWithAppleEnabled else { return }
        Task {
            do {
                switch result {
                case .success(let authorization):
                    try await AuthManager.shared.processAuthorization(authorization)
                    await applySignedInProfileFromApple()
                case .failure(let error):
                    let nsError = error as NSError
                    if nsError.domain == ASAuthorizationError.errorDomain,
                       nsError.code == ASAuthorizationError.canceled.rawValue {
                        return
                    }
                    throw error
                }
            } catch {
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }

    private func applySignedInProfileFromApple() async {
        if let name = AuthManager.shared.displayNameFromApple, !name.isEmpty {
            profile?.displayName = name
        }
        if let email = AuthManager.shared.emailFromApple {
            profile?.email = email
        }
        saveProfile()
        await reload()
    }

    func signOut() {
        guard FeatureFlags.signInWithAppleEnabled else { return }
        Task {
            do {
                try await AuthManager.shared.signOut()
                await reload()
            } catch {
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }

    func exportData(type: ExportType, from: Date, to: Date) {
        Task {
            do {
                cleanupExportFile()
                exportURL = try dependencies.exportDataUseCase.execute(type: type, from: from, to: to)
                showExportSheet = true
            } catch {
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }

    /// PRIVACY FIX: remove temporary export files after the share sheet closes.
    func cleanupExportFile() {
        if let url = exportURL {
            try? FileManager.default.removeItem(at: url)
        }
        exportURL = nil
    }

    func clearAllData() {
        Task {
            do {
                try dependencies.wipeAllUserData()
                ProfileStore.shared.deleteAvatarImage()
                invalidateAvatarCache()
                await reload()
            } catch {
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }

    func deleteAccount() {
        guard FeatureFlags.signInWithAppleEnabled else { return }
        Task {
            do {
                try await AuthManager.shared.deleteAccount()
                clearAllData()
            } catch {
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }
}
