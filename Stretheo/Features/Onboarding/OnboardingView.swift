//
//  OnboardingView.swift
//  Stretheo
//

import SwiftUI

struct OnboardingView: View {
    @Environment(\.appDependencies) private var dependencies
    @Environment(AppRouter.self) private var router

    @State private var page = 0
    @State private var isFinishing = false

    var body: some View {
        TabView(selection: $page) {
            welcomePage.tag(0)
            PrivacyExplainerView().tag(1)
            HealthKitExplainerView(
                onContinue: handleHealthContinue,
                onSkip: handleHealthSkip
            )
            .tag(2)
            NotificationExplainerView(
                onContinue: handleNotificationContinue,
                onSkip: handleNotificationSkip
            )
            .tag(3)
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .background(AppColors.appBackground)
        .safeAreaInset(edge: .bottom) {
            if page < 2 {
                VStack(spacing: 16) {
                    OnboardingPageIndicator(currentStep: page, totalSteps: 4)
                    PrimaryButton(
                        title: String(localized: "onboarding.continue"),
                        isLoading: false,
                        isEnabled: true,
                        action: advanceWelcomeOrPrivacy
                    )
                }
                .padding(AppSpacing.md)
            }
        }
        .overlay {
            if isFinishing {
                ProgressView()
                    .controlSize(.large)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(AppColors.tertiarySystemFill.opacity(0.5))
            }
        }
    }

    private var welcomePage: some View {
        VStack(spacing: AppSpacing.lg) {
            Spacer(minLength: AppSpacing.xl)

            Image("LaunchIcon")
                .resizable()
                .scaledToFit()
                .frame(width: 100, height: 100)
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))

            Text(String(localized: "onboarding.welcome.title"))
                .font(AppTypography.screenTitle)
                .multilineTextAlignment(.center)

            Text(String(localized: "onboarding.welcome.subtitle"))
                .font(AppTypography.body)
                .foregroundStyle(AppColors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, AppSpacing.lg)

            Spacer()
        }
        .padding(AppSpacing.xl)
    }

    private func advanceWelcomeOrPrivacy() {
        guard page < 2 else { return }
        withAnimation { page += 1 }
    }

    private func handleHealthContinue() {
        Task {
            // Request first — do not assume success by setting the preference beforehand.
            try? await dependencies.healthSyncUseCase.requestAuthorization()
            AppSettings.healthSyncEnabled =
                dependencies.healthKitManager.healthSyncPreferenceAfterAuthorizationPrompt()
            withAnimation { page = 3 }
        }
    }

    private func handleHealthSkip() {
        AppSettings.healthSyncEnabled = false
        withAnimation { page = 3 }
    }

    private func handleNotificationContinue() {
        isFinishing = true
        Task {
            dependencies.notificationManager.registerCategories()
            // Request first — do not assume success by setting the preference beforehand.
            _ = try? await dependencies.notificationManager.requestAuthorization()
            let status = await dependencies.notificationManager.authorizationStatus()
            // Match Gate 5: authorized / provisional / ephemeral count as enabled.
            AppSettings.notificationsEnabled =
                status == .authorized || status == .provisional || status == .ephemeral
            await router.finishOnboarding(dependencies: dependencies)
            isFinishing = false
        }
    }

    private func handleNotificationSkip() {
        AppSettings.notificationsEnabled = false
        isFinishing = true
        Task {
            await router.finishOnboarding(dependencies: dependencies)
            isFinishing = false
        }
    }
}
