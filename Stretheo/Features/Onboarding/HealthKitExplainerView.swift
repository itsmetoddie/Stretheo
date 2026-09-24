//
//  HealthKitExplainerView.swift
//  Stretheo
//

import SwiftUI

struct HealthKitExplainerView: View {
    let onContinue: () -> Void
    let onSkip: () -> Void

    private let metrics: [(icon: String, title: String, description: String)] = [
        ("waveform.path.ecg", "Heart Rate Variability", "Primary signal for stress detection — 30% of your score"),
        ("heart.fill", "Heart Rate", "Current and resting heart rate — 24% of your score"),
        ("lungs.fill", "Respiratory Rate", "Breathing rate while at rest — 13% of your score"),
        ("bed.double.fill", "Sleep", "Duration and quality from the previous night — 20% of your score"),
        ("thermometer.medium", "Wrist Temperature", "Subtle thermoregulatory changes — part of 13% composite"),
        ("figure.walk", "Activity", "Type and intensity of movement — part of 13% composite")
    ]

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 24) {
                    Image(systemName: "heart.text.square.fill")
                        .font(.system(size: 56))
                        .foregroundStyle(Color.accentColor)
                        .padding(.top, 32)

                    VStack(spacing: 8) {
                        Text("Stretheo Reads Your Health Data")
                            .font(.title2)
                            .fontWeight(.bold)
                            .multilineTextAlignment(.center)

                        Text("To calculate your stress score, Stretheo needs access to these metrics from Apple Watch and Health.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                    }

                    VStack(spacing: 14) {
                        ForEach(metrics, id: \.title) { metric in
                            HStack(spacing: 14) {
                                Image(systemName: metric.icon)
                                    .font(.title3)
                                    .foregroundStyle(Color.accentColor)
                                    .frame(width: 32)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(metric.title)
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                    Text(metric.description)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                            }
                            .padding(.horizontal, 20)
                        }
                    }

                    VStack(spacing: 6) {
                        Image(systemName: "lock.shield.fill")
                            .font(.title3)
                            .foregroundStyle(.green)
                        Text("Your health data stays on your device and is never shared without your explicit consent.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                    }
                    .padding(.top, 12)
                    .padding(.bottom, 24)
                }
            }

            VStack(spacing: 24) {
                OnboardingPageIndicator(currentStep: 2, totalSteps: 4)

                VStack(spacing: 12) {
                    Button(action: onContinue) {
                        Text("Continue")
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
}
