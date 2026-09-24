//
//  CloudKitArticleService.swift
//  Stretheo
//

import CloudKit
import Foundation
import OSLog

final class CloudKitArticleService: @unchecked Sendable {
    /// Nil when `FeatureFlags.iCloudSyncEnabled` is false — no `CKContainer` is ever created.
    private let database: CKDatabase?

    init(container: CKContainer? = nil) {
        if FeatureFlags.iCloudCapabilityAvailable {
            let resolved = container ?? CKContainer(identifier: ServiceConstants.cloudKitContainerID)
            database = resolved.publicCloudDatabase
        } else {
            database = nil
        }
    }

    func fetchArticles() async throws -> [Article] {
        guard FeatureFlags.iCloudSyncEnabled, let database else {
            return SampleArticles.makeArticles()
        }

        let query = CKQuery(recordType: "Article", predicate: NSPredicate(value: true))
        query.sortDescriptors = [NSSortDescriptor(key: "publishedDate", ascending: false)]

        do {
            let (results, _) = try await database.records(matching: query)
            return results.compactMap { _, result -> Article? in
                guard let record = try? result.get() else { return nil }
                return mapRecord(record)
            }
        } catch let error as CKError where error.code == .unknownItem {
            StretheoLog.swiftData.error(
                "CloudKit articles query unknownItem — falling back to sample articles: \(error.localizedDescription, privacy: .public)"
            )
            return SampleArticles.makeArticles()
        } catch {
            StretheoLog.swiftData.error(
                "CloudKit articles fetch failed — falling back to sample articles: \(error.localizedDescription, privacy: .public)"
            )
            return SampleArticles.makeArticles()
        }
    }

    private func mapRecord(_ record: CKRecord) -> Article? {
        guard let title = record["title"] as? String,
              let category = record["category"] as? String,
              let summary = record["summary"] as? String,
              let content = record["content"] as? String,
              let author = record["author"] as? String,
              let publishedDate = record["publishedDate"] as? Date else {
            return nil
        }
        return Article(
            cloudKitRecordID: record.recordID.recordName,
            title: title,
            category: category,
            summary: summary,
            content: content,
            author: author,
            publishedDate: publishedDate,
            imageURL: record["imageURL"] as? String,
            isFeatured: record["isFeatured"] as? Bool ?? false
        )
    }
}
