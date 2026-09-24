//
//  ExportLogRepository.swift
//  Stretheo
//

import Foundation
import SwiftData

// MARK: - Protocol

@MainActor
protocol ExportLogRepositoryProtocol: AnyObject {
    func log(exportType: ExportType, from start: Date, to end: Date) throws -> ExportLog
    func recentLogs(limit: Int) throws -> [ExportLog]
    func deleteAll() throws
}

// MARK: - SwiftData Implementation

@MainActor
final class SwiftDataExportLogRepository: ExportLogRepositoryProtocol {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    func log(exportType: ExportType, from start: Date, to end: Date) throws -> ExportLog {
        let profile = try RepositoryHelpers.fetchOrCreateUserProfile(in: context)
        let log = ExportLog(exportType: exportType, dateFrom: start, dateTo: end, userProfile: profile)
        context.insert(log)
        try RepositoryHelpers.save(context, contextLabel: "ExportLog.log")
        return log
    }

    func recentLogs(limit: Int = 20) throws -> [ExportLog] {
        var descriptor = FetchDescriptor<ExportLog>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        descriptor.fetchLimit = limit
        do {
            return try context.fetch(descriptor)
        } catch {
            throw AppError.persistence(error, context: "ExportLog.fetch")
        }
    }

    func deleteAll() throws {
        do {
            try context.delete(model: ExportLog.self)
            try RepositoryHelpers.save(context, contextLabel: "ExportLog.deleteAll")
        } catch {
            throw AppError.persistence(error, context: "ExportLog.deleteAll")
        }
    }
}
