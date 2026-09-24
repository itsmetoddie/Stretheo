//
//  AppRouter.swift
//  Stretheo
//

import SwiftUI

enum AppState: Equatable {
    case launching
    case onboarding
    case main
}

@MainActor
@Observable
final class AppRouter {
    var appState: AppState
    var selectedTab: AppTab = .home
    var presentedBreathing = false
    var selectedBreathingTechnique: BreathingTechnique?
    var selectedArticleID: UUID?
    var pendingDeepLink: AppDeepLink?

    init() {
        appState = .launching
    }

    // MARK: - Launch

    func finishLaunch() {
        let next: AppState = AppSettings.hasCompletedOnboarding ? .main : .onboarding
        withAnimation(.easeInOut(duration: 0.4)) {
            appState = next
        }
        if next == .main {
            consumePendingDeepLink()
        }
    }

    // MARK: - Onboarding

    func finishOnboarding(dependencies: AppDependencies) async {
        _ = try? dependencies.profileRepository.fetchOrCreateProfile()

        AppSettings.hasCompletedOnboarding = true
        WatchConnectivityManager.shared.pushNotificationSettingsToWatch()
        withAnimation(.easeInOut(duration: 0.4)) {
            appState = .main
        }
        consumePendingDeepLink()
    }

    // MARK: - Deep links

    func handle(_ deepLink: AppDeepLink) {
        pendingDeepLink = deepLink
        guard appState == .main else { return }
        applyDeepLink(deepLink)
        pendingDeepLink = nil
    }

    func consumePendingDeepLink() {
        guard appState == .main, let link = pendingDeepLink else { return }
        applyDeepLink(link)
        pendingDeepLink = nil
    }

    func handleNotificationUserInfo(_ userInfo: [AnyHashable: Any]) {
        if userInfo[NotificationManager.deepLinkKey] as? String == NotificationManager.deepLinkMoodValue {
            handle(.mood)
        }
    }

    private func applyDeepLink(_ deepLink: AppDeepLink) {
        switch deepLink {
        case .home:
            selectedTab = .home
        case .mood:
            selectedTab = .mood
        case .breathing:
            selectedTab = .home
            selectedBreathingTechnique = BreathingTechnique.catalog.first
            // Idempotent with openBreathing — avoid stacking covers on repeated deep links.
            if !presentedBreathing {
                presentedBreathing = true
            }
        case .article(let id):
            selectedTab = .articles
            selectedArticleID = id
        case .settings:
            selectedTab = .settings
        }
    }

    func openBreathing(technique: BreathingTechnique? = nil) {
        selectedTab = .home
        selectedBreathingTechnique = technique ?? BreathingTechnique.catalog.first
        // Idempotent: fullScreenCover(isPresented:) will not stack a second session if already true.
        guard !presentedBreathing else { return }
        presentedBreathing = true
    }
}

enum AppTab: String, CaseIterable, Identifiable {
    case home
    case mood
    case history
    case articles
    case settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .home: String(localized: "tab.home")
        case .mood: String(localized: "tab.mood")
        case .history: String(localized: "tab.history")
        case .articles: String(localized: "tab.articles")
        case .settings: String(localized: "tab.settings")
        }
    }

    var systemImage: String {
        switch self {
        case .home: "heart.text.square.fill"
        case .mood: "face.smiling"
        case .history: "chart.xyaxis.line"
        case .articles: "book.fill"
        case .settings: "gearshape.fill"
        }
    }
}
