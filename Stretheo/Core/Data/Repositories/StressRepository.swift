//
//  StressRepository.swift
//  Stretheo
//

import Foundation
import OSLog
import SwiftData

// MARK: - Protocol

@MainActor
protocol StressRepositoryProtocol: AnyObject {
    func save(result: StressResult, input: HealthInput, trigger: TriggerType) async throws -> StressMeasurement
    func saveFromWatch(level: Int, measuredAt: Date, data: [String: Any]) async throws -> StressMeasurement
    func measurements(from start: Date, to end: Date, limit: Int) throws -> [StressMeasurement]
    func latestMeasurement() throws -> StressMeasurement?
    func todayMeasurements() throws -> [StressMeasurement]
    func todayAverageStressLevel() throws -> Int?
    func deleteAll() throws
    func recentMeasurements(limit: Int) throws -> [StressMeasurement]
    func pruneHealthSnapshotsOlderThan(days: Int) throws -> Int
}

// MARK: - SwiftData Implementation

@MainActor
final class SwiftDataStressRepository: StressRepositoryProtocol {
    private let context: ModelContext
    private let stressDataActor: StressDataActor

    init(container: ModelContainer, stressDataActor: StressDataActor) {
        self.context = container.mainContext
        self.stressDataActor = stressDataActor
    }

    func save(result: StressResult, input: HealthInput, trigger: TriggerType) async throws -> StressMeasurement {
        let profile = try RepositoryHelpers.fetchOrCreateUserProfile(in: context)
        let measuredAt = Date()
        let id = UUID()
        do {
            try await stressDataActor.saveStressMeasurement(
                id: id,
                stressLevel: result.level,
                stressCategoryRaw: result.category.rawValue,
                triggerTypeRaw: trigger.rawValue,
                measuredAt: measuredAt,
                createdAt: Date(),
                profileID: profile.id,
                healthInput: input
            )
        } catch {
            StretheoLog.stressRepository.error(
                "saveStressMeasurement failed: \(error.localizedDescription)"
            )
            throw AppError.persistence(error, context: "StressMeasurement.save")
        }
        guard let measurement = try measurement(withID: id) else {
            StretheoLog.stressRepository.error("saveStressMeasurement succeeded but fetch by id failed")
            throw AppError.persistence(
                NSError(domain: "StressRepository", code: 1),
                context: "StressMeasurement.save.fetch"
            )
        }
        return measurement
    }

    func saveFromWatch(level: Int, measuredAt: Date, data: [String: Any]) async throws -> StressMeasurement {
        if let existing = try measurement(withMeasuredAt: measuredAt) {
            StretheoLog.stressRepository.debug("Skipping Watch save — duplicate measuredAt")
            return existing
        }

        let categoryRaw = data[WatchConnectivityPayloadKey.category.rawValue] as? String
        let category = categoryRaw.flatMap(StressCategory.init(rawValue:))
            ?? StressCategory.from(level: level)
        let hrv = data[WatchConnectivityPayloadKey.hrv.rawValue] as? Double
        let heartRate = data[WatchConnectivityPayloadKey.heartRate.rawValue] as? Double

        do {
            try await stressDataActor.saveFromWatch(
                stressLevel: level,
                stressCategoryRaw: category.rawValue,
                measuredAt: measuredAt,
                hrv: hrv,
                heartRate: heartRate
            )
        } catch {
            StretheoLog.stressRepository.error(
                "saveFromWatch failed: \(error.localizedDescription)"
            )
            throw AppError.persistence(error, context: "StressMeasurement.saveFromWatch")
        }

        if let existing = try measurement(withMeasuredAt: measuredAt) {
            return existing
        }
        if let latest = try latestMeasurement() {
            return latest
        }

        StretheoLog.stressRepository.error("saveFromWatch succeeded but fetch failed")
        throw AppError.persistence(
            NSError(domain: "StressRepository", code: 2),
            context: "StressMeasurement.saveFromWatch.fetch"
        )
    }

    func measurements(from start: Date, to end: Date, limit: Int = 500) throws -> [StressMeasurement] {
        var descriptor = FetchDescriptor<StressMeasurement>(
            predicate: #Predicate { $0.measuredAt >= start && $0.measuredAt < end },
            sortBy: [SortDescriptor(\.measuredAt)]
        )
        descriptor.fetchLimit = limit
        do {
            return try context.fetch(descriptor)
        } catch {
            throw AppError.persistence(error, context: "StressMeasurement.fetch")
        }
    }

    func latestMeasurement() throws -> StressMeasurement? {
        var descriptor = FetchDescriptor<StressMeasurement>(
            sortBy: [SortDescriptor(\.measuredAt, order: .reverse)]
        )
        descriptor.fetchLimit = 1
        do {
            return try context.fetch(descriptor).first
        } catch {
            throw AppError.persistence(error, context: "StressMeasurement.latest")
        }
    }

    func todayMeasurements() throws -> [StressMeasurement] {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: Date())
        guard let end = calendar.date(byAdding: .day, value: 1, to: start) else {
            return try measurements(from: start, to: Date())
        }
        return try measurements(from: start, to: end)
    }

    func todayAverageStressLevel() throws -> Int? {
        let today = try todayMeasurements()
        guard !today.isEmpty else { return nil }
        let total = today.reduce(0) { $0 + $1.stressLevel }
        return total / today.count
    }

    func deleteAll() throws {
        do {
            try context.delete(model: StressMeasurement.self)
            try context.delete(model: HealthSnapshot.self)
            try RepositoryHelpers.save(context, contextLabel: "StressMeasurement.deleteAll")
        } catch {
            throw AppError.persistence(error, context: "StressMeasurement.deleteAll")
        }
    }

    func recentMeasurements(limit: Int) throws -> [StressMeasurement] {
        var descriptor = FetchDescriptor<StressMeasurement>(
            sortBy: [SortDescriptor(\.measuredAt, order: .reverse)]
        )
        descriptor.fetchLimit = limit
        do {
            return try context.fetch(descriptor)
        } catch {
            throw AppError.persistence(error, context: "StressMeasurement.recent")
        }
    }

    func pruneHealthSnapshotsOlderThan(days: Int) throws -> Int {
        let calendar = Calendar.current
        guard let cutoff = calendar.date(byAdding: .day, value: -days, to: Date()) else { return 0 }

        let descriptor = FetchDescriptor<HealthSnapshot>(
            predicate: #Predicate { $0.recordedAt < cutoff }
        )
        do {
            let snapshots = try context.fetch(descriptor)
            for snapshot in snapshots {
                snapshot.measurement?.healthSnapshot = nil
                context.delete(snapshot)
            }
            if !snapshots.isEmpty {
                try RepositoryHelpers.save(context, contextLabel: "HealthSnapshot.prune")
            }
            return snapshots.count
        } catch {
            throw AppError.persistence(error, context: "HealthSnapshot.prune")
        }
    }

    // MARK: - Private

    private func measurement(withID id: UUID) throws -> StressMeasurement? {
        let targetID = id
        var descriptor = FetchDescriptor<StressMeasurement>(
            predicate: #Predicate { $0.id == targetID }
        )
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    private func measurement(withMeasuredAt measuredAt: Date) throws -> StressMeasurement? {
        let start = measuredAt.addingTimeInterval(-0.5)
        let end = measuredAt.addingTimeInterval(0.5)
        var descriptor = FetchDescriptor<StressMeasurement>(
            predicate: #Predicate { $0.measuredAt >= start && $0.measuredAt <= end }
        )
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }
}
