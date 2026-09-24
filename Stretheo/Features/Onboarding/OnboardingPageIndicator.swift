//
//  OnboardingPageIndicator.swift
//  Stretheo
//

import SwiftUI

struct OnboardingPageIndicator: View {
    let currentStep: Int
    let totalSteps: Int

    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<totalSteps, id: \.self) { index in
                Circle()
                    .fill(index == currentStep ? Color.accentColor : Color(.systemGray4))
                    .frame(width: 8, height: 8)
            }
        }
        .accessibilityLabel("Step \(currentStep + 1) of \(totalSteps)")
    }
}
