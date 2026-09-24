//
//  AppRootView.swift
//  Stretheo
//

import SwiftUI

struct AppRootView: View {
    @Environment(\.appDependencies) private var dependencies
    @Environment(AppRouter.self) private var router

    var body: some View {
        Group {
            switch router.appState {
            case .launching:
                Color.clear
            case .onboarding:
                OnboardingView()
                .transition(.opacity)
            case .main:
                MainTabView(dependencies: dependencies, router: router)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.4), value: router.appState)
    }
}
