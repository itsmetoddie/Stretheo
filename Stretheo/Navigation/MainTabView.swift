//
//  MainTabView.swift
//  Stretheo
//

import SwiftData
import SwiftUI

struct MainTabView: View {
    @Environment(AppRouter.self) private var router

    private let dependencies: AppDependencies

    @State private var homeViewModel: HomeViewModel
    @State private var moodViewModel: MoodViewModel
    @State private var historyViewModel: HistoryViewModel
    @State private var articlesViewModel: ArticlesViewModel
    @State private var settingsViewModel: SettingsViewModel

    init(dependencies: AppDependencies, router: AppRouter) {
        self.dependencies = dependencies
        _homeViewModel = State(wrappedValue: HomeViewModel(dependencies: dependencies, router: router))
        _moodViewModel = State(wrappedValue: MoodViewModel(dependencies: dependencies))
        _historyViewModel = State(wrappedValue: HistoryViewModel(dependencies: dependencies))
        _articlesViewModel = State(wrappedValue: ArticlesViewModel(dependencies: dependencies, router: router))
        _settingsViewModel = State(wrappedValue: SettingsViewModel(dependencies: dependencies))
    }

    var body: some View {
        @Bindable var router = router

        TabView(selection: $router.selectedTab) {
            Tab(value: AppTab.home) {
                tabRoot(for: .home) {
                    HomeView(viewModel: homeViewModel)
                }
            } label: {
                Label(AppTab.home.title, systemImage: AppTab.home.systemImage)
            }

            Tab(value: AppTab.mood) {
                tabRoot(for: .mood) {
                    MoodView(viewModel: moodViewModel)
                }
            } label: {
                Label(AppTab.mood.title, systemImage: AppTab.mood.systemImage)
            }

            Tab(value: AppTab.history) {
                tabRoot(for: .history) {
                    HistoryView(viewModel: historyViewModel)
                }
            } label: {
                Label(AppTab.history.title, systemImage: AppTab.history.systemImage)
            }

            Tab(value: AppTab.articles) {
                tabRoot(for: .articles) {
                    ArticlesView(viewModel: articlesViewModel)
                        .modelContainer(dependencies.articleContainer)
                }
            } label: {
                Label(AppTab.articles.title, systemImage: AppTab.articles.systemImage)
            }

            Tab(value: AppTab.settings) {
                tabRoot(for: .settings) {
                    SettingsView(viewModel: settingsViewModel)
                }
            } label: {
                Label(AppTab.settings.title, systemImage: AppTab.settings.systemImage)
            }
        }
        .tabViewStyle(.automatic)
        .background(Color(.systemBackground))
        .animation(.easeInOut(duration: 0.18), value: router.selectedTab)
        .onChange(of: router.selectedTab) { previous, selected in
            guard previous != selected else { return }
            HapticFeedback.soft()
        }
        .fullScreenCover(isPresented: $router.presentedBreathing) {
            BreathingSessionView(
                technique: router.selectedBreathingTechnique ?? BreathingTechnique.catalog[0]
            )
        }
        .onAppear {
            router.consumePendingDeepLink()
        }
    }

    @ViewBuilder
    private func tabRoot<Content: View>(for tab: AppTab, @ViewBuilder content: () -> Content) -> some View {
        NavigationStack {
            content()
                .id(tab)
                .transition(.opacity)
                .animation(.easeInOut(duration: 0.18), value: router.selectedTab)
        }
    }
}
