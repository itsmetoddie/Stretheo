//
//  BreathingTechnique.swift
//  Stretheo
//

import Foundation
import SwiftUI

enum BreathPhaseKind: String, Sendable {
    case inhale
    case hold
    case exhale
}

struct BreathingPhase: Identifiable, Sendable {
    let id: UUID
    let name: String
    let instruction: String
    let duration: TimeInterval
    let kind: BreathPhaseKind

    init(
        id: UUID = UUID(),
        name: String,
        instruction: String,
        duration: TimeInterval,
        kind: BreathPhaseKind? = nil
    ) {
        self.id = id
        self.name = name
        self.instruction = instruction
        self.duration = duration
        self.kind = kind ?? Self.inferredKind(from: name)
    }

    private static func inferredKind(from name: String) -> BreathPhaseKind {
        let lower = name.lowercased()
        if lower.contains("inhale") { return .inhale }
        if lower.contains("exhale") { return .exhale }
        return .hold
    }
}

struct BreathingTechnique: Identifiable, Sendable {
    private static let id478 = UUID(uuidString: "A1000001-0000-4000-8000-000000000001")
    private static let idBox = UUID(uuidString: "A1000002-0000-4000-8000-000000000002")
    private static let idCoherent = UUID(uuidString: "A1000003-0000-4000-8000-000000000003")

    let id: UUID
    let name: String
    let subtitle: String
    let description: String
    let phases: [BreathingPhase]
    let recommendedCycles: Int
    /// Total session length in seconds (recommendedCycles × one cycle).
    let totalDuration: Int
    let recommendedStressLevel: ClosedRange<Int>
    let systemImage: String
    let accentColor: Color

    var cycleDuration: TimeInterval {
        phases.map(\.duration).reduce(0, +)
    }

    var formattedDuration: String {
        let minutes = max(1, Int((Double(totalDuration) / 60.0).rounded()))
        return "~\(minutes) min"
    }

    /// Short label for the Home technique picker (index 2 = Coherent).
    var pickerLabel: String {
        if id == BreathingTechnique.coherent.id {
            return "Coherent"
        }
        return name
    }

    /// Ordered techniques — index 0 is 4-7-8 (default selection).
    static var all: [BreathingTechnique] { catalog }

    static var fourSevenEight: BreathingTechnique { catalog[0] }
    static var boxBreathing: BreathingTechnique { catalog[1] }
    static var coherent: BreathingTechnique { catalog[2] }

    static let catalog: [BreathingTechnique] = {
        guard let id478, let idBox, let idCoherent else { return [] }
        return [
            BreathingTechnique(
                id: id478,
                name: "4-7-8 Breathing",
                subtitle: "Anxiety & sleep relief",
                description: "Developed by Dr. Andrew Weil, this technique activates the parasympathetic nervous system. The extended exhale releases tension and promotes calm.",
                phases: [
                    BreathingPhase(
                        name: "Inhale",
                        instruction: "Breathe in through your nose",
                        duration: 4,
                        kind: .inhale
                    ),
                    BreathingPhase(
                        name: "Hold",
                        instruction: "Hold your breath",
                        duration: 7,
                        kind: .hold
                    ),
                    BreathingPhase(
                        name: "Exhale",
                        instruction: "Exhale completely through your mouth",
                        duration: 8,
                        kind: .exhale
                    )
                ],
                recommendedCycles: 4,
                totalDuration: 76,
                recommendedStressLevel: 67...100,
                systemImage: "timer",
                accentColor: Color(.systemBlue)
            ),
            BreathingTechnique(
                id: idBox,
                name: "Box Breathing",
                subtitle: "Focus & stress control",
                description: "Used by Navy SEALs and first responders to maintain calm under pressure. Four equal phases create a rhythmic pattern that regulates the autonomic nervous system.",
                phases: [
                    BreathingPhase(
                        name: "Inhale",
                        instruction: "Breathe in through your nose",
                        duration: 4,
                        kind: .inhale
                    ),
                    BreathingPhase(
                        name: "Hold",
                        instruction: "Hold at the top",
                        duration: 4,
                        kind: .hold
                    ),
                    BreathingPhase(
                        name: "Exhale",
                        instruction: "Breathe out through your mouth",
                        duration: 4,
                        kind: .exhale
                    ),
                    BreathingPhase(
                        name: "Hold",
                        instruction: "Hold at the bottom",
                        duration: 4,
                        kind: .hold
                    )
                ],
                recommendedCycles: 5,
                totalDuration: 120,
                recommendedStressLevel: 34...100,
                systemImage: "square",
                accentColor: Color(.systemPurple)
            ),
            BreathingTechnique(
                id: idCoherent,
                name: "Coherent Breathing",
                subtitle: "HRV & nervous system balance",
                description: "Breathing at 5 breaths per minute maximises heart rate variability and balances the sympathetic and parasympathetic nervous systems. Clinically proven to reduce stress, anxiety and depression.",
                phases: [
                    BreathingPhase(
                        name: "Inhale",
                        instruction: "Breathe in slowly through your nose",
                        duration: 6,
                        kind: .inhale
                    ),
                    BreathingPhase(
                        name: "Exhale",
                        instruction: "Breathe out slowly and completely",
                        duration: 6,
                        kind: .exhale
                    )
                ],
                recommendedCycles: 10,
                totalDuration: 120,
                recommendedStressLevel: 0...66,
                systemImage: "waveform.path",
                accentColor: Color(.systemMint)
            )
        ]
    }()
}
