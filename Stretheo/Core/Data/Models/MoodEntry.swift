//
//  MoodEntry.swift
//  Stretheo
//

import Foundation
import SwiftData

@Model
final class MoodEntry {
    #Index<MoodEntry>([\.entryDate])

    var id: UUID = UUID()
    var moodScore: Int = 0
    var moodWord: String?
    var entryDate: Date = Date()
    var createdAt: Date = Date()
    var cloudKitRecordID: String?

    var userProfile: UserProfile?

    init(
        id: UUID = UUID(),
        moodScore: Int,
        moodWord: String? = nil,
        entryDate: Date = Date(),
        createdAt: Date = Date(),
        cloudKitRecordID: String? = nil,
        userProfile: UserProfile? = nil
    ) {
        self.id = id
        self.moodScore = moodScore
        self.moodWord = Self.normalizedMoodWord(moodWord)
        self.entryDate = entryDate
        self.createdAt = createdAt
        self.cloudKitRecordID = cloudKitRecordID
        self.userProfile = userProfile
    }

    static func normalizedMoodWord(_ word: String?) -> String? {
        guard let word else { return nil }
        let trimmed = word.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return String(trimmed.prefix(60))
    }

    static func validateScore(_ score: Int) throws {
        guard (1...5).contains(score) else {
            throw AppError.invalidData("Mood score must be between 1 and 5.")
        }
    }
}
