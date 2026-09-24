//
//  SyncService.swift
//  Stretheo
//
//  Coordinates iCloud / CloudKit account state with profile + UserDefaults.
//  SwiftData CloudKit container mode is fixed at launch — toggling sync requires an app restart.
//

import Foundation

struct SyncSnapshot: Sendable {
    let account: CloudKitAccountStatus
    let isSyncEnabledInApp: Bool
    let isSyncEnabledOnProfile: Bool
    let requiresRestartToApply: Bool
    let lastCheckedAt: Date
}

@MainActor
final class SyncService {
    private let cloudKitSyncService: CloudKitSyncService
    private let profileRepository: UserProfileRepositoryProtocol
    private(set) var lastSnapshot: SyncSnapshot?

    init(
        cloudKitSyncService: CloudKitSyncService = CloudKitSyncService(),
        profileRepository: UserProfileRepositoryProtocol
    ) {
        self.cloudKitSyncService = cloudKitSyncService
        self.profileRepository = profileRepository
    }

    func accountStatus() async -> CloudKitAccountStatus {
        await refreshSnapshot().account
    }

    func refreshSnapshot() async -> SyncSnapshot {
        let account = await cloudKitSyncService.accountStatus()
        let profileEnabled = (try? profileRepository.fetchOrCreateProfile().iCloudSyncEnabled) ?? false
        let defaultsEnabled = AppSettings.iCloudSyncEnabled
        let snapshot = SyncSnapshot(
            account: account,
            isSyncEnabledInApp: defaultsEnabled,
            isSyncEnabledOnProfile: profileEnabled,
            requiresRestartToApply: defaultsEnabled != profileEnabled,
            lastCheckedAt: Date()
        )
        lastSnapshot = snapshot
        AppSettings.lastICloudStatusCheck = snapshot.lastCheckedAt
        return snapshot
    }

    func setICloudSyncEnabled(_ enabled: Bool) async throws {
        guard FeatureFlags.iCloudCapabilityAvailable else {
            throw AppError.cloudKitUnavailable
        }

        if enabled {
            let account = await cloudKitSyncService.accountStatus()
            guard account.status == .available else {
                throw AppError.cloudKitUnavailable
            }
        }

        let profile = try profileRepository.fetchOrCreateProfile()
        profile.iCloudSyncEnabled = enabled
        try profileRepository.save()
    }

    func canEnableSync(snapshot: SyncSnapshot? = nil) -> Bool {
        guard FeatureFlags.iCloudCapabilityAvailable else { return false }
        let status = snapshot?.account.status ?? lastSnapshot?.account.status
        return status == .available
    }

    var restartRequiredMessage: String {
        String(localized: "icloud.sync.restart_required")
    }
}
