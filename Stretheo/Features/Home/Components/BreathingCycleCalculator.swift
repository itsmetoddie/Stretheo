//
//  BreathingCycleCalculator.swift
//  Stretheo
//

import Foundation

struct BreathingCycleState: Sendable, Equatable {
    let scale: CGFloat
    let label: String
    let instruction: String
    let phaseProgress: Double
    let phaseKind: BreathPhaseKind
    let phaseIndex: Int
    let phaseDuration: TimeInterval
    let secondsRemaining: Int
}

enum BreathingCycleCalculator {
    static func state(at time: TimeInterval, technique: BreathingTechnique) -> BreathingCycleState {
        let durations = technique.phases.map(\.duration)
        let total = durations.reduce(0, +)
        guard total > 0 else {
            let phase = technique.phases.first
            return BreathingCycleState(
                scale: 1,
                label: phase?.name ?? technique.name,
                instruction: phase?.instruction ?? "",
                phaseProgress: 0,
                phaseKind: .inhale,
                phaseIndex: 0,
                phaseDuration: 1,
                secondsRemaining: 1
            )
        }

        let position = time.truncatingRemainder(dividingBy: total)
        var accumulated: TimeInterval = 0
        for (index, phase) in technique.phases.enumerated() {
            accumulated += phase.duration
            if position < accumulated {
                let local = position - (accumulated - phase.duration)
                let progress = phase.duration > 0 ? local / phase.duration : 0
                let scale: CGFloat = switch phase.kind {
                case .inhale: CGFloat(0.72 + progress * 0.38)
                case .exhale: CGFloat(1.10 - progress * 0.38)
                case .hold: 1.08
                }
                let remaining = max(0, Int(ceil(phase.duration * (1 - progress))))
                return BreathingCycleState(
                    scale: scale,
                    label: phase.name,
                    instruction: phase.instruction,
                    phaseProgress: progress,
                    phaseKind: phase.kind,
                    phaseIndex: index,
                    phaseDuration: phase.duration,
                    secondsRemaining: remaining
                )
            }
        }
        let phase = technique.phases.first
        return BreathingCycleState(
            scale: 1,
            label: phase?.name ?? technique.name,
            instruction: phase?.instruction ?? "",
            phaseProgress: 0,
            phaseKind: .inhale,
            phaseIndex: 0,
            phaseDuration: 1,
            secondsRemaining: 1
        )
    }
}
