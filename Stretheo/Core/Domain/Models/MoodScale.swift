//
//  MoodScale.swift
//  Stretheo
//

import Foundation

struct MoodScaleEntry: Identifiable, Sendable {
    let id: Int
    let emoji: String
    let label: String
    let description: String

    static let all: [MoodScaleEntry] = [
        MoodScaleEntry(id: 1, emoji: "😩", label: String(localized: "mood.scale.1.label"), description: String(localized: "mood.scale.1.description")),
        MoodScaleEntry(id: 2, emoji: "😟", label: String(localized: "mood.scale.2.label"), description: String(localized: "mood.scale.2.description")),
        MoodScaleEntry(id: 3, emoji: "😐", label: String(localized: "mood.scale.3.label"), description: String(localized: "mood.scale.3.description")),
        MoodScaleEntry(id: 4, emoji: "🙂", label: String(localized: "mood.scale.4.label"), description: String(localized: "mood.scale.4.description")),
        MoodScaleEntry(id: 5, emoji: "😊", label: String(localized: "mood.scale.5.label"), description: String(localized: "mood.scale.5.description"))
    ]
}
