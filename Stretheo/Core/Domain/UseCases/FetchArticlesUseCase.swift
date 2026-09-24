//
//  FetchArticlesUseCase.swift
//  Stretheo
//

import Foundation

struct FetchArticlesUseCase {
    private let articleRepository: ArticleRepositoryProtocol
    private let cloudKitArticleService: CloudKitArticleService

    init(
        articleRepository: ArticleRepositoryProtocol,
        cloudKitArticleService: CloudKitArticleService = CloudKitArticleService()
    ) {
        self.articleRepository = articleRepository
        self.cloudKitArticleService = cloudKitArticleService
    }

    @MainActor
    func execute(forceRefresh: Bool = false) async throws -> [Article] {
        let cached = try articleRepository.allArticles()
        if !cached.isEmpty, !forceRefresh {
            return cached
        }

        if FeatureFlags.iCloudSyncEnabled {
            do {
                let remote = try await cloudKitArticleService.fetchArticles()
                if !remote.isEmpty {
                    try articleRepository.upsertArticles(remote)
                }
            } catch {
                if cached.isEmpty { throw error }
            }
        } else if cached.isEmpty {
            try articleRepository.upsertArticles(SampleArticles.makeArticles())
        }

        return try articleRepository.allArticles()
    }
}
