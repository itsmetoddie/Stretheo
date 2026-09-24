//
//  CloudKitSyncService.swift
//  Stretheo
//

import CloudKit
import Foundation

enum ICloudAccountState: Sendable, Equatable {
    case available
    case noAccount
    case restricted
    case couldNotDetermine
    case temporarilyUnavailable
    case featureDisabled
    case unknown
}

struct CloudKitAccountStatus: Sendable {
    let status: ICloudAccountState
    let lastSyncDescription: String
}

final class CloudKitSyncService: @unchecked Sendable {
    /// Nil when `FeatureFlags.iCloudSyncEnabled` is false — no `CKContainer` is ever created.
    private let container: CKContainer?

    /// Pass a container only in tests or when the feature flag is enabled.
    init(container: CKContainer? = nil) {
        if FeatureFlags.iCloudCapabilityAvailable {
            self.container = container ?? CKContainer(identifier: ServiceConstants.cloudKitContainerID)
        } else {
            self.container = nil
        }
    }

    func accountStatus() async -> CloudKitAccountStatus {
        guard FeatureFlags.iCloudCapabilityAvailable, let container else {
            return CloudKitAccountStatus(
                status: .featureDisabled,
                lastSyncDescription: String(localized: "icloud.status.disabled")
            )
        }

        do {
            let status = try await container.accountStatus()
            return CloudKitAccountStatus(
                status: mapAccountStatus(status),
                lastSyncDescription: description(for: status)
            )
        } catch {
            return CloudKitAccountStatus(
                status: .couldNotDetermine,
                lastSyncDescription: String(localized: "icloud.status.error")
            )
        }
    }

    private func mapAccountStatus(_ status: CKAccountStatus) -> ICloudAccountState {
        switch status {
        case .available: .available
        case .noAccount: .noAccount
        case .restricted: .restricted
        case .couldNotDetermine: .couldNotDetermine
        case .temporarilyUnavailable: .temporarilyUnavailable
        @unknown default: .unknown
        }
    }

    private func description(for status: CKAccountStatus) -> String {
        switch status {
        case .available: String(localized: "icloud.status.available")
        case .noAccount: String(localized: "icloud.status.no_account")
        case .restricted: String(localized: "icloud.status.restricted")
        case .couldNotDetermine: String(localized: "icloud.status.unknown")
        case .temporarilyUnavailable: String(localized: "icloud.status.temp_unavailable")
        @unknown default: String(localized: "icloud.status.unknown")
        }
    }
}
