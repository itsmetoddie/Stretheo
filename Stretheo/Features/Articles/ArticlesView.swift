//
//  ArticlesView.swift
//  Stretheo
//

import OSLog
import SwiftData
import SwiftUI

struct ArticlesView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var viewModel: ArticlesViewModel

    @State private var visibleArticleLimit = Self.pageSize

    private static let pageSize = 30
    private let sectionSpacing: CGFloat = AppSpacing.md

    private var visibleArticles: [Article] {
        Array(viewModel.displayedArticles.prefix(visibleArticleLimit))
    }

    private var hasMoreArticles: Bool {
        viewModel.displayedArticles.count > visibleArticleLimit
    }

    var body: some View {
        ZStack {
            Color(.systemBackground)
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                LazyVStack(alignment: .leading, spacing: sectionSpacing) {
                    TabScrollSubtitle(text: String(localized: "articles.subtitle"))

                    ArticlesSearchBar(text: $viewModel.searchText)

                    if let featured = viewModel.featured {
                        NavigationLink {
                            ArticleDetailView(article: featured)
                        } label: {
                            FeaturedArticleCard(article: featured)
                        }
                        .buttonStyle(.plain)
                        .animatedCard(index: 0)
                    }

                    allArticlesSection
                }
                .padding(.horizontal, AppSpacing.screenHorizontal)
                .padding(.bottom, AppSpacing.tabBarClearance)
            }
            .scrollContentBackground(.hidden)
            .background(Color(.systemBackground))
            .scrollDismissesKeyboard(.interactively)
        }
        .dismissKeyboardOnTap()
        .stretheoTabNavigation(title: String(localized: "tab.articles"))
        .onChange(of: viewModel.searchText) { _, _ in
            visibleArticleLimit = Self.pageSize
            viewModel.updateDisplayedArticles()
        }
        .onChange(of: viewModel.displayedArticles.count) { _, _ in
            // Keep the window valid if search/reload shrinks the filtered set.
            if visibleArticleLimit > viewModel.displayedArticles.count
                && viewModel.displayedArticles.count > Self.pageSize {
                visibleArticleLimit = viewModel.displayedArticles.count
            }
        }
        .onAppear {
            seedSampleArticlesIfNeeded()
            visibleArticleLimit = Self.pageSize
            Task {
                await viewModel.reloadArticles()
            }
        }
        .overlay {
            if viewModel.isLoading && viewModel.articles.isEmpty {
                ProgressView()
                    .controlSize(.large)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                    .background(Color(.systemBackground).opacity(0.6))
            }
        }
        .errorBanner(viewModel.errorMessage, isPresented: $viewModel.showError)
    }

    private var allArticlesSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            SectionHeaderView(
                systemImage: "book.fill",
                title: String(localized: "tab.articles")
            )
            .animatedCard(index: viewModel.featured == nil ? 0 : 1)

            LazyVStack(spacing: 0) {
                ForEach(Array(visibleArticles.enumerated()), id: \.element.id) { index, article in
                    NavigationLink {
                        ArticleDetailView(article: article)
                    } label: {
                        ArticleRowView(article: article)
                    }
                    .buttonStyle(.plain)
                    .animatedCard(index: (viewModel.featured == nil ? 0 : 1) + index)

                    if index < visibleArticles.count - 1 {
                        Color(.separator)
                            .frame(height: 0.5)
                            .padding(.leading, 68)
                    }
                }

                if hasMoreArticles {
                    Button {
                        visibleArticleLimit += Self.pageSize
                    } label: {
                        Text(String(localized: "common.load_more"))
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, AppSpacing.md)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(Color.accentColor)
                    .accessibilityLabel(String(localized: "common.load_more"))
                }
            }
            .padding(.horizontal, AppSpacing.md)
            .padding(.bottom, AppSpacing.md)
            .homeScreenCard(padding: 0, elevated: false)
        }
    }

    private func seedSampleArticlesIfNeeded() {
        var descriptor = FetchDescriptor<Article>()
        descriptor.fetchLimit = 1
        let existing = (try? modelContext.fetch(descriptor)) ?? []
        guard existing.isEmpty else { return }

        for article in SampleArticles.makeArticles() {
            modelContext.insert(article)
        }

        do {
            try modelContext.save()
        } catch {
            StretheoLog.swiftData.error(
                "Sample article seed save failed: \(error.localizedDescription, privacy: .public)"
            )
        }
    }
}
