//
//  NotificationLogRepository.swift
//  Stretheo
//

import Foundation
import SwiftData

// MARK: - Protocol

@MainActor
protocol NotificationLogRepositoryProtocol: AnyObject {
    @discardableResult
    func log(
        stressLevel: Int,
        message: String,
        triggeredByMeasurement: StressMeasurement?,
        source: NotificationSource
    ) throws -> NotificationLog
    func recentlyNotifiedFromWatch(for measurementID: UUID) throws -> Bool
    func recentLogs(limit: Int) throws -> [NotificationLog]
    func markRead(id: UUID) throws
    func deleteAll() throws
}

// MARK: - SwiftData Implementation

@MainActor
final class SwiftDataNotificationLogRepository: NotificationLogRepositoryProtocol {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    @discardableResult
    func log(
        stressLevel: Int,
        message: String,
        triggeredByMeasurement: StressMeasurement? = nil,
        source: NotificationSource = .iphone
    ) throws -> NotificationLog {
        let entry = NotificationLog(
            stressLevelAtTrigger: stressLevel,
            messageText: message,
            source: source
        )
        // CLEANED: insert log before setting relationships (SwiftData requires persisted objects for links)
        context.insert(entry)

        entry.userProfile = try RepositoryHelpers.fetchOrCreateUserProfile(in: context)

        if let measurement = resolveMeasurementInContext(triggeredByMeasurement) {
            entry.triggeredByMeasurement = measurement
            measurement.triggeredNotification = entry
        }

        try RepositoryHelpers.save(context, contextLabel: "NotificationLog.log")
        return entry
    }

    func recentlyNotifiedFromWatch(for measurementID: UUID) throws -> Bool {
        let windowStart = Date().addingTimeInterval(-NotificationPolicy.watchIPhoneDedupeWindow)
        let watchSource = NotificationSource.watch.rawValue
        var descriptor = FetchDescriptor<NotificationLog>(
            predicate: #Predicate { log in
                log.sourceRaw == watchSource && log.sentAt >= windowStart
            },
            sortBy: [SortDescriptor(\.sentAt, order: .reverse)]
        )
        descriptor.fetchLimit = 20
        let logs = try context.fetch(descriptor)
        return logs.contains { $0.triggeredByMeasurement?.id == measurementID }
    }

    /// Links a measurement only when it exists in this repository's `ModelContext`.
    private func resolveMeasurementInContext(_ measurement: StressMeasurement?) -> StressMeasurement? {
        guard let measurement else { return nil }
        if let measurementContext = measurement.modelContext, measurementContext === context {
            return measurement
        }
        return context.model(for: measurement.persistentModelID) as? StressMeasurement
    }

    func recentLogs(limit: Int = 50) throws -> [NotificationLog] {
        var descriptor = FetchDescriptor<NotificationLog>(
            sortBy: [SortDescriptor(\.sentAt, order: .reverse)]
        )
        descriptor.fetchLimit = limit
        do {
            return try context.fetch(descriptor)
        } catch {
            throw AppError.persistence(error, context: "NotificationLog.fetch")
        }
    }

    func markRead(id: UUID) throws {
        let targetID = id
        var descriptor = FetchDescriptor<NotificationLog>(
            predicate: #Predicate { $0.id == targetID }
        )
        descriptor.fetchLimit = 1
        do {
            guard let log = try context.fetch(descriptor).first else {
                throw AppError.recordNotFound("NotificationLog")
            }
            log.isRead = true
            try RepositoryHelpers.save(context, contextLabel: "NotificationLog.markRead")
        } catch let error as AppError {
            throw error
        } catch {
            throw AppError.persistence(error, context: "NotificationLog.markRead")
        }
    }

    func deleteAll() throws {
        do {
            try context.delete(model: NotificationLog.self)
            try RepositoryHelpers.save(context, contextLabel: "NotificationLog.deleteAll")
        } catch {
            throw AppError.persistence(error, context: "NotificationLog.deleteAll")
        }
    }
}
