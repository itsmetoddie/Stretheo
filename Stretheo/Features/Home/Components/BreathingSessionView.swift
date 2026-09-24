//
//  BreathingSessionView.swift
//  Stretheo
//
//  Calm sky / aurora breathing session — adaptive MeshGradient + glass orb.
//

import SwiftUI

// MARK: - Mesh phase palette

private enum BreathingMeshPhase: Equatable {
    case inhale
    case hold
    case exhale
    case hold2
}

private enum BreathingCalmPalette {
    static let meshPoints: [SIMD2<Float>] = [
        SIMD2(0.0, 0.0), SIMD2(0.5, 0.0), SIMD2(1.0, 0.0),
        SIMD2(0.0, 0.5), SIMD2(0.5, 0.5), SIMD2(1.0, 0.5),
        SIMD2(0.0, 1.0), SIMD2(0.5, 1.0), SIMD2(1.0, 1.0)
    ]

    static let lightNavy = Color(hex: "#1a3a5c")

    static func colorsForPhase(_ phase: BreathingMeshPhase, colorScheme: ColorScheme) -> [Color] {
        meshFromPalette(palette(for: phase, colorScheme: colorScheme))
    }

    static func phasePrimaryText(colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? .white : lightNavy
    }

    static func phaseSecondaryText(colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? Color.white.opacity(0.75) : lightNavy.opacity(0.72)
    }

    static func endButtonBackground(colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? Color.white.opacity(0.15) : Color.white.opacity(0.25)
    }

    static func endButtonForeground(colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? .white : lightNavy
    }

    private static func palette(for phase: BreathingMeshPhase, colorScheme: ColorScheme) -> [Color] {
        if colorScheme == .dark {
            switch phase {
            case .inhale:
                return [
                    Color(hex: "#0a2a1a"),
                    Color(hex: "#0d3d2a"),
                    Color(hex: "#051a10"),
                    Color(hex: "#0d3d2a"),
                    Color(hex: "#0a2a1a")
                ]
            case .hold:
                return [
                    Color(hex: "#1a1a3a"),
                    Color(hex: "#1a2040"),
                    Color(hex: "#0d1020"),
                    Color(hex: "#1a2040"),
                    Color(hex: "#1a1a3a")
                ]
            case .exhale, .hold2:
                return restingDarkPalette
            }
        }

        switch phase {
        case .inhale:
            return [
                Color(hex: "#ccfbf1"),
                Color(hex: "#a5f3fc"),
                Color(hex: "#7dd3fc"),
                Color(hex: "#bae6fd"),
                Color(hex: "#e0f7ff")
            ]
        case .hold:
            return [
                Color("BreathingSky").opacity(0.85),
                Color("BreathingSky"),
                Color("BreathingMint").opacity(0.9),
                Color("BreathingSky"),
                Color("BreathingMint")
            ]
        case .exhale:
            return [
                Color("BreathingMint"),
                Color("BreathingMint").opacity(0.9),
                Color("BreathingMint"),
                Color("BreathingSky").opacity(0.85),
                Color("BreathingMint").opacity(0.95)
            ]
        case .hold2:
            return [
                Color("BreathingMint").opacity(0.9),
                Color("BreathingSky"),
                Color("BreathingMint"),
                Color("BreathingSky").opacity(0.8),
                Color("BreathingMint")
            ]
        }
    }

    private static let restingDarkPalette: [Color] = [
        Color(hex: "#0a1628"),
        Color(hex: "#0d2137"),
        Color(hex: "#071320"),
        Color(hex: "#0d2137"),
        Color(hex: "#0a1628")
    ]

    /// Maps five palette swatches onto the 3×3 mesh vertices.
    private static func meshFromPalette(_ palette: [Color]) -> [Color] {
        let a = palette[0]
        let b = palette[1]
        let c = palette[2]
        let d = palette[3]
        let e = palette[4]
        return [a, b, c, b, e, d, c, d, e]
    }
}

// MARK: - Bubble scale targets (phase change only)

private extension BreathingCycleState {
    var sessionBubbleScale: CGFloat? {
        switch phaseKind {
        case .inhale: 1.0
        case .exhale: 0.55
        case .hold: nil
        }
    }
}

// MARK: - Main view

struct BreathingSessionView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let technique: BreathingTechnique

    @State private var sessionStart = Date()
    @State private var bubbleScale: CGFloat = 0.55
    @State private var gradientColors: [Color] = BreathingCalmPalette.colorsForPhase(.exhale, colorScheme: .light)
    @State private var currentMeshPhase: BreathingMeshPhase = .exhale
    @State private var activePhaseIndex: Int = -1
    @State private var phaseLabel = ""
    @State private var secondsRemaining = 0
    @State private var isSessionComplete = false
    @State private var showCompletionCheckmark = false

    private let bubbleBaseSize: CGFloat = 248
    private let bubbleScaleMin: CGFloat = 0.55

    private var sessionDuration: TimeInterval {
        Double(technique.totalDuration)
    }

    private var elapsed: TimeInterval {
        Date().timeIntervalSince(sessionStart)
    }

    private var completedCycles: Int {
        guard technique.cycleDuration > 0 else { return 0 }
        return min(technique.recommendedCycles, Int(elapsed / technique.cycleDuration))
    }

    var body: some View {
        ZStack {
            TimelineView(.animation(minimumInterval: 1 / 30)) { timeline in
                BreathingCalmBackground(
                    gradientColors: gradientColors,
                    meshPhase: currentMeshPhase,
                    shimmerTime: timeline.date.timeIntervalSinceReferenceDate,
                    colorScheme: colorScheme
                )
            }

            if isSessionComplete {
                completionView
            } else {
                activeSessionView
            }
        }
        .ignoresSafeArea()
        .toolbar(.hidden, for: .navigationBar)
        .navigationBarHidden(true)
        .onAppear(perform: resetSession)
        .onChange(of: colorScheme) { _, scheme in
            gradientColors = BreathingCalmPalette.colorsForPhase(currentMeshPhase, colorScheme: scheme)
        }
        .task(id: sessionStart) {
            await runPhaseTransitionLoop()
        }
        .task(id: sessionStart) {
            await runCountdownLoop()
        }
    }

    // MARK: - Active session

    private var activeSessionView: some View {
        VStack {
            Spacer()

            BreathingGlassBubble(
                scale: bubbleScale,
                baseSize: bubbleBaseSize,
                phaseLabel: phaseLabel,
                secondsRemaining: secondsRemaining,
                accentColor: technique.accentColor,
                colorScheme: colorScheme
            )

            Spacer()

            cycleProgressDots
                .padding(.bottom, 16)

            endSessionButton
                .padding(.horizontal, AppSpacing.lg)
                .padding(.bottom, 32)
        }
    }

    private var cycleProgressDots: some View {
        HStack(spacing: 6) {
            ForEach(0..<technique.recommendedCycles, id: \.self) { index in
                Circle()
                    .fill(
                        index < completedCycles
                            ? Color.white.opacity(0.8)
                            : Color.white.opacity(0.25)
                    )
                    .frame(width: 6, height: 6)
            }
        }
        .accessibilityLabel(cycleProgressAccessibilityLabel)
    }

    private var cycleProgressAccessibilityLabel: String {
        String(
            format: String(localized: "breathing.session.cycles_progress"),
            completedCycles,
            technique.recommendedCycles
        )
    }

    // MARK: - Completion

    private var completionView: some View {
        VStack(spacing: AppSpacing.lg) {
            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 72))
                .foregroundStyle(Color(.systemGreen))
                .scaleEffect(showCompletionCheckmark ? 1 : 0.5)
                .opacity(showCompletionCheckmark ? 1 : 0)
                .animation(
                    reduceMotion ? nil : .spring(response: 0.55, dampingFraction: 0.72),
                    value: showCompletionCheckmark
                )

            Text(String(localized: "Session Complete"))
                .font(.title2.weight(.bold))
                .foregroundStyle(BreathingCalmPalette.phasePrimaryText(colorScheme: colorScheme))

            VStack(spacing: AppSpacing.sm) {
                Text(
                    String(
                        format: String(localized: "You completed %lld cycles of %@"),
                        technique.recommendedCycles,
                        technique.name
                    )
                )
                    .font(.body)
                    .foregroundStyle(BreathingCalmPalette.phaseSecondaryText(colorScheme: colorScheme))
                    .multilineTextAlignment(.center)

                Text(String(localized: "Well done! Your nervous system is now in a calmer state."))
                    .font(.subheadline)
                    .foregroundStyle(BreathingCalmPalette.phaseSecondaryText(colorScheme: colorScheme))
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, AppSpacing.xl)

            Spacer()

            doneButton
                .padding(.horizontal, AppSpacing.lg)
                .padding(.bottom, AppSpacing.xl)
        }
        .padding(.horizontal, AppSpacing.md)
        .onAppear {
            if reduceMotion {
                showCompletionCheckmark = true
            } else {
                withAnimation(.spring(response: 0.55, dampingFraction: 0.72)) {
                    showCompletionCheckmark = true
                }
            }
            HapticFeedback.success()
        }
    }

    private var doneButton: some View {
        Button {
            dismiss()
        } label: {
            Text(String(localized: "Done"))
                .font(.headline.weight(.semibold))
                .foregroundStyle(BreathingCalmPalette.endButtonForeground(colorScheme: colorScheme))
                .frame(maxWidth: .infinity)
                .padding(.vertical, AppSpacing.md)
        }
        .buttonStyle(.plain)
        .background {
            RoundedRectangle(cornerRadius: AppRadius.button, style: .continuous)
                .fill(BreathingCalmPalette.endButtonBackground(colorScheme: colorScheme))
                .overlay {
                    RoundedRectangle(cornerRadius: AppRadius.button, style: .continuous)
                        .stroke(Color.white.opacity(colorScheme == .dark ? 0.2 : 0.35), lineWidth: 1)
                }
        }
        .accessibilityLabel(String(localized: "Done"))
    }

    // MARK: - Session lifecycle

    private func resetSession() {
        sessionStart = Date()
        isSessionComplete = false
        showCompletionCheckmark = false
        bubbleScale = bubbleScaleMin
        activePhaseIndex = -1

        let frame = currentFrame()
        let meshPhase = meshPhaseKey(for: frame)
        currentMeshPhase = meshPhase
        gradientColors = BreathingCalmPalette.colorsForPhase(meshPhase, colorScheme: colorScheme)

        phaseLabel = frame.label
        secondsRemaining = frame.secondsRemaining
    }

    private func meshPhaseKey(for frame: BreathingCycleState) -> BreathingMeshPhase {
        switch frame.phaseKind {
        case .inhale:
            return .inhale
        case .exhale:
            return .exhale
        case .hold:
            let index = frame.phaseIndex
            if index > 0, technique.phases[index - 1].kind == .exhale {
                return .hold2
            }
            return .hold
        }
    }

    private func runPhaseTransitionLoop() async {
        while !Task.isCancelled {
            if elapsed >= sessionDuration {
                await finishSession()
                return
            }

            let frame = currentFrame()

            if frame.phaseIndex != activePhaseIndex {
                applyPhaseChange(frame, animated: true)
            }

            let sleepDuration = remainingTimeInPhase(for: frame)
            guard sleepDuration > 0 else {
                try? await Task.sleep(for: .milliseconds(16))
                continue
            }
            try? await Task.sleep(for: .seconds(sleepDuration))
        }
    }

    private func runCountdownLoop() async {
        while !Task.isCancelled {
            if elapsed >= sessionDuration {
                await finishSession()
                return
            }

            let frame = currentFrame()
            phaseLabel = frame.label
            secondsRemaining = frame.secondsRemaining
            try? await Task.sleep(for: .seconds(1))
        }
    }

    @MainActor
    private func finishSession() async {
        guard !isSessionComplete else { return }
        isSessionComplete = true
    }

    private func currentFrame() -> BreathingCycleState {
        let clamped = min(elapsed, max(sessionDuration - 0.001, 0))
        return BreathingCycleCalculator.state(at: clamped, technique: technique)
    }

    private func remainingTimeInPhase(for frame: BreathingCycleState) -> TimeInterval {
        let inPhase = max(0, frame.phaseDuration * (1 - frame.phaseProgress))
        let untilSessionEnd = max(0, sessionDuration - elapsed)
        return min(inPhase, untilSessionEnd)
    }

    private func applyPhaseChange(_ frame: BreathingCycleState, animated: Bool) {
        activePhaseIndex = frame.phaseIndex
        let nextPhase = meshPhaseKey(for: frame)
        let colors = BreathingCalmPalette.colorsForPhase(nextPhase, colorScheme: colorScheme)
        let duration = max(frame.phaseDuration, 0.01)
        let targetScale = frame.sessionBubbleScale

        if animated {
            withAnimation(.easeInOut(duration: duration)) {
                currentMeshPhase = nextPhase
                gradientColors = colors
                if let targetScale {
                    bubbleScale = targetScale
                }
            }
        } else {
            currentMeshPhase = nextPhase
            gradientColors = colors
            if let targetScale {
                bubbleScale = targetScale
            }
        }
    }

    private var endSessionButton: some View {
        Button {
            dismiss()
        } label: {
            Text(String(localized: "breathing.close"))
                .font(.headline.weight(.semibold))
                .foregroundStyle(BreathingCalmPalette.endButtonForeground(colorScheme: colorScheme))
                .frame(maxWidth: .infinity)
                .padding(.vertical, AppSpacing.md)
        }
        .buttonStyle(.plain)
        .background {
            RoundedRectangle(cornerRadius: AppRadius.button, style: .continuous)
                .fill(BreathingCalmPalette.endButtonBackground(colorScheme: colorScheme))
                .overlay {
                    RoundedRectangle(cornerRadius: AppRadius.button, style: .continuous)
                        .stroke(Color.white.opacity(colorScheme == .dark ? 0.2 : 0.35), lineWidth: 1)
                }
        }
        .accessibilityLabel(String(localized: "breathing.close"))
    }
}

// MARK: - Animated mesh background

private struct BreathingCalmBackground: View {
    let gradientColors: [Color]
    let meshPhase: BreathingMeshPhase
    let shimmerTime: TimeInterval
    let colorScheme: ColorScheme

    private var isHolding: Bool { meshPhase == .hold || meshPhase == .hold2 }

    var body: some View {
        ZStack {
            MeshGradient(
                width: 3,
                height: 3,
                points: BreathingCalmPalette.meshPoints,
                colors: gradientColors,
                background: gradientColors.first ?? (colorScheme == .dark ? Color(hex: "#071320") : .white)
            )

            if isHolding {
                holdShimmerOverlay
            }

            RadialGradient(
                colors: [
                    Color.white.opacity(colorScheme == .dark ? 0.12 : 0.35),
                    Color.clear
                ],
                center: .center,
                startRadius: 40,
                endRadius: 420
            )
            .blendMode(.softLight)
        }
        .ignoresSafeArea()
    }

    @ViewBuilder
    private var holdShimmerOverlay: some View {
        let accent = meshPhase == .hold2
            ? (Color.cyan.opacity(0.45), Color(hex: "#1a2040").opacity(0.6))
            : (Color(hex: "#0d3d2a").opacity(0.5), Color.cyan.opacity(0.35))

        LinearGradient(
            colors: [accent.0, .clear, accent.1],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .opacity((colorScheme == .dark ? 0.55 : 0.5) + 0.12 * sin(shimmerTime * 1.8))
        .blendMode(.softLight)
    }
}

// MARK: - Glass bubble

private struct BreathingGlassBubble: View {
    let scale: CGFloat
    let baseSize: CGFloat
    let phaseLabel: String
    let secondsRemaining: Int
    let accentColor: Color
    let colorScheme: ColorScheme

    private var diameter: CGFloat { baseSize * scale }

    private var isDark: Bool { colorScheme == .dark }

    private var bubbleFill: Color {
        Color.white.opacity(isDark ? 0.08 : 0.25)
    }

    private var bubbleStroke: Color {
        Color.white.opacity(isDark ? 0.25 : 0.4)
    }

    private var cyanTintOpacity: Double {
        isDark ? 0.14 : 0.08
    }

    private var glowOpacity: Double {
        isDark ? 0.4 : 0.3
    }

    var body: some View {
        ZStack {
            Circle()
                .fill(accentColor.opacity(cyanTintOpacity))
                .frame(width: diameter, height: diameter)

            bubbleBody
                .frame(width: diameter, height: diameter)

            phaseTextStack
        }
    }

    private var phaseTextStack: some View {
        VStack(spacing: AppSpacing.xs) {
            Text(phaseLabel)
                .font(.title2.weight(.bold))
                .foregroundStyle(BreathingCalmPalette.phasePrimaryText(colorScheme: colorScheme))
                .id(phaseLabel)
                .transition(.opacity)
                .animation(.easeInOut(duration: 0.3), value: phaseLabel)

            Text("\(secondsRemaining)")
                .font(.title3)
                .foregroundStyle(BreathingCalmPalette.phasePrimaryText(colorScheme: colorScheme))
                .monospacedDigit()
                .id(secondsRemaining)
                .transition(.opacity)
                .animation(.easeInOut(duration: 0.25), value: secondsRemaining)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(phaseLabel), \(secondsRemaining) seconds")
    }

    @ViewBuilder
    private var bubbleBody: some View {
        if #available(iOS 26.0, *), !isDark {
            Circle()
                .fill(bubbleFill)
                .background(.ultraThinMaterial, in: Circle())
                .glassEffect(in: Circle())
                .overlay {
                    Circle().stroke(bubbleStroke, lineWidth: 1.5)
                }
                .shadow(color: accentColor.opacity(glowOpacity), radius: 30)
        } else {
            Circle()
                .fill(bubbleFill)
                .overlay {
                    Circle().stroke(bubbleStroke, lineWidth: 1.5)
                }
                .shadow(color: accentColor.opacity(glowOpacity), radius: 30)
        }
    }
}

