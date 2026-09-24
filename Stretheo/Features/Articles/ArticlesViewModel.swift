//
//  ArticlesViewModel.swift
//  Stretheo
//

import Foundation

@MainActor
@Observable
final class ArticlesViewModel {
    private let dependencies: AppDependencies
    private let router: AppRouter
    private var loadTask: Task<Void, Never>?
    private var hasLoaded = false

    var articles: [Article] = []
    var featured: Article?
    var searchText = ""
    private(set) var displayedArticles: [Article] = []
    var isLoading = false
    var errorMessage: String?
    var showError = false

    init(dependencies: AppDependencies, router: AppRouter) {
        self.dependencies = dependencies
        self.router = router
        scheduleInitialLoad()
    }

    func loadIfNeeded() async {
        guard !hasLoaded else { return }
        hasLoaded = true
        await loadData()
    }

    func reloadArticles() async {
        await loadData()
    }

    func updateDisplayedArticles() {
        let list = articles.filter { $0.id != featured?.id }
        guard !searchText.isEmpty else {
            displayedArticles = list
            return
        }
        displayedArticles = list.filter {
            $0.title.localizedCaseInsensitiveContains(searchText)
                || $0.summary.localizedCaseInsensitiveContains(searchText)
        }
    }

    func cancelPendingWork() {
        loadTask?.cancel()
    }

    private func scheduleInitialLoad() {
        loadTask = Task { await loadIfNeeded() }
    }

    private func loadData() async {
        isLoading = true
        defer { isLoading = false }
        do {
            articles = try await dependencies.fetchArticlesUseCase.execute()
            featured = try dependencies.articleRepository.featuredArticle()
            updateDisplayedArticles()
            if let id = router.selectedArticleID,
               let article = articles.first(where: { $0.id == id }) {
                router.selectedArticleID = article.id
            }
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }
}
