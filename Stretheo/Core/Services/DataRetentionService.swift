//
//  DataRetentionService.swift
//  Stretheo
//
//  Privacy: prune aggregated health snapshots after retention window (on-device only).
//

import Foundation
import OSLog

@MainActor
enum DataRetentionService {
    static func pruneExpiredHealthSnapshots(
        repository: StressRepositoryProtocol,
        retentionDays: Int = ServiceConstants.healthSnapshotRetentionDays
    ) {
        do {
            let removed = try repository.pruneHealthSnapshotsOlderThan(days: retentionDays)
            if removed > 0 {
                StretheoLog.privacy.debug("[Privacy]")
            }
        } catch {
            StretheoLog.privacy.error(
                "Health snapshot retention prune failed: \(error.localizedDescription, privacy: .public)"
            )
        }
    }
}
