//
//  NotificationExplainerView.swift
//  Stretheo
//

import SwiftUI

struct NotificationExplainerView: View {
    let onContinue: () -> Void
    let onSkip: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 24) {
                    Image(systemName: "bell.badge.fill")
                        .font(.system(size: 56))
                        .foregroundStyle(Color.accentColor)
                        .padding(.top, 32)

                    VStack(spacing: 8) {
                        Text("Get Notified When It Matters")
                            .font(.title2)
                            .fontWeight(.bold)
                            .multilineTextAlignment(.center)

                        Text("Stretheo sends a notification only when your stress level crosses your personal threshold — never more than 3 times a day.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                    }

                    VStack(alignment: .leading, spacing: 14) {
                        explainerRow(icon: "slider.horizontal.3", text: "You choose the threshold that triggers an alert")
                        explainerRow(icon: "moon.fill", text: "Quiet hours are respected automatically")
                        explainerRow(icon: "checkmark.circle.fill", text: "You can turn this off anytime in Settings")
                    }
                    .padding(.horizontal, 28)
                    .padding(.top, 8)
                    .padding(.bottom, 24)
                }
            }

            VStack(spacing: 24) {
                OnboardingPageIndicator(currentStep: 3, totalSteps: 4)

                VStack(spacing: 12) {
                    Button(action: onContinue) {
                        Text("Enable Notifications")
                            .font(.body)
                            .fontWeight(.semibold)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(Color.accentColor)
                            )
                    }

                    Button(action: onSkip) {
                        Text("Not Now")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundStyle(.primary.opacity(0.7))
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 16)
        }
    }

    @ViewBuilder
    private func explainerRow(icon: String, text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.body)
                .foregroundStyle(Color.accentColor)
                .frame(width: 24)
            Text(text)
                .font(.subheadline)
            Spacer()
        }
    }
}
