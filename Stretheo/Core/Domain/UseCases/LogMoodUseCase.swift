//
//  LogMoodUseCase.swift
//  Stretheo
//

import Foundation

struct LogMoodUseCase {
    private let moodRepository: MoodRepositoryProtocol

    init(moodRepository: MoodRepositoryProtocol) {
        self.moodRepository = moodRepository
    }

    @MainActor
    func execute(score: Int, word: String?, entryDate: Date) async throws -> MoodEntry {
        try await moodRepository.save(score: score, word: word, entryDate: entryDate)
    }
}
