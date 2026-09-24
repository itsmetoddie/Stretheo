//
//  ArticleRepository.swift
//  Stretheo
//

import Foundation
import SwiftData

// MARK: - Protocol

@MainActor
protocol ArticleRepositoryProtocol: AnyObject {
    func allArticles() throws -> [Article]
    func article(id: UUID) throws -> Article?
    func featuredArticle() throws -> Article?
    func upsertArticles(_ articles: [Article]) throws
    func search(query: String) throws -> [Article]
    func deleteAll() throws
}

// MARK: - SwiftData Implementation

@MainActor
final class SwiftDataArticleRepository: ArticleRepositoryProtocol {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    func allArticles() throws -> [Article] {
        let descriptor = FetchDescriptor<Article>(
            sortBy: [SortDescriptor(\.publishedDate, order: .reverse)]
        )
        do {
            return try context.fetch(descriptor)
        } catch {
            throw AppError.persistence(error, context: "Article.fetchAll")
        }
    }

    func article(id: UUID) throws -> Article? {
        let targetID = id
        var descriptor = FetchDescriptor<Article>(
            predicate: #Predicate { $0.id == targetID }
        )
        descriptor.fetchLimit = 1
        do {
            return try context.fetch(descriptor).first
        } catch {
            throw AppError.persistence(error, context: "Article.fetchByID")
        }
    }

    func featuredArticle() throws -> Article? {
        var featuredDescriptor = FetchDescriptor<Article>(
            predicate: #Predicate { $0.isFeatured == true },
            sortBy: [SortDescriptor(\.publishedDate, order: .reverse)]
        )
        featuredDescriptor.fetchLimit = 1
        do {
            if let featured = try context.fetch(featuredDescriptor).first {
                return featured
            }
            var fallback = FetchDescriptor<Article>(
                sortBy: [SortDescriptor(\.publishedDate, order: .reverse)]
            )
            fallback.fetchLimit = 1
            return try context.fetch(fallback).first
        } catch {
            throw AppError.persistence(error, context: "Article.featured")
        }
    }

    func upsertArticles(_ articles: [Article]) throws {
        for article in articles {
            let recordID = article.cloudKitRecordID
            var descriptor = FetchDescriptor<Article>(
                predicate: #Predicate { $0.cloudKitRecordID == recordID }
            )
            descriptor.fetchLimit = 1

            do {
                if let existing = try context.fetch(descriptor).first {
                    existing.title = article.title
                    existing.category = article.category
                    existing.summary = article.summary
                    existing.content = article.content
                    existing.author = article.author
                    existing.publishedDate = article.publishedDate
                    existing.imageURL = article.imageURL
                    existing.isFeatured = article.isFeatured
                    existing.cachedAt = Date()
                } else {
                    context.insert(article)
                }
            } catch {
                throw AppError.persistence(error, context: "Article.upsert")
            }
        }
        try RepositoryHelpers.save(context, contextLabel: "Article.upsertSave")
    }

    func search(query: String) throws -> [Article] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return try allArticles() }
        let articles = try allArticles()
        return articles.filter {
            $0.title.localizedCaseInsensitiveContains(trimmed)
                || $0.summary.localizedCaseInsensitiveContains(trimmed)
                || $0.category.localizedCaseInsensitiveContains(trimmed)
        }
    }

    func deleteAll() throws {
        do {
            try context.delete(model: Article.self)
            try RepositoryHelpers.save(context, contextLabel: "Article.deleteAll")
        } catch {
            throw AppError.persistence(error, context: "Article.deleteAll")
        }
    }
}
