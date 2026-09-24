//
//  MoodRepository.swift
//  Stretheo
//

import Foundation
import OSLog
import SwiftData

// MARK: - Protocol

@MainActor
protocol MoodRepositoryProtocol: AnyObject {
    func save(score: Int, word: String?, entryDate: Date) async throws -> MoodEntry
    func entries(from start: Date, to end: Date, limit: Int) throws -> [MoodEntry]
    func entries(on day: Date) throws -> [MoodEntry]
    func todayEntries() throws -> [MoodEntry]
    func dominantMoodByDay(monthContaining date: Date) throws -> [Date: Int]
    func deleteAll() throws
}

// MARK: - SwiftData Implementation

@MainActor
final class SwiftDataMoodRepository: MoodRepositoryProtocol {
    private let context: ModelContext
    private let stressDataActor: StressDataActor

    init(context: ModelContext, stressDataActor: StressDataActor) {
        self.context = context
        self.stressDataActor = stressDataActor
    }

    func save(score: Int, word: String?, entryDate: Date) async throws -> MoodEntry {
        try MoodEntry.validateScore(score)
        let profile = try RepositoryHelpers.fetchOrCreateUserProfile(in: context)
        let id = UUID()
        let createdAt = Date()
        do {
            try await stressDataActor.saveMoodEntry(
                id: id,
                moodScore: score,
                note: word ?? "",
                entryDate: entryDate,
                createdAt: createdAt,
                profileID: profile.id
            )
        } catch {
            StretheoLog.swiftData.error("saveMoodEntry failed: \(error.localizedDescription)")
            throw AppError.persistence(error, context: "MoodEntry.save")
        }
        guard let entry = try entry(withID: id) else {
            StretheoLog.swiftData.error("saveMoodEntry succeeded but fetch by id failed")
            throw AppError.persistence(
                NSError(domain: "MoodRepository", code: 1),
                context: "MoodEntry.save.fetch"
            )
        }
        return entry
    }

    func entries(from start: Date, to end: Date, limit: Int = 500) throws -> [MoodEntry] {
        var descriptor = FetchDescriptor<MoodEntry>(
            predicate: #Predicate { $0.entryDate >= start && $0.entryDate < end },
            sortBy: [SortDescriptor(\.entryDate)]
        )
        descriptor.fetchLimit = limit
        do {
            return try context.fetch(descriptor)
        } catch {
            throw AppError.persistence(error, context: "MoodEntry.fetch")
        }
    }

    func entries(on day: Date) throws -> [MoodEntry] {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: day)
        guard let end = calendar.date(byAdding: .day, value: 1, to: start) else {
            return try entries(from: start, to: Date())
        }
        return try entries(from: start, to: end)
    }

    func todayEntries() throws -> [MoodEntry] {
        try entries(on: Date())
    }

    func dominantMoodByDay(monthContaining date: Date) throws -> [Date: Int] {
        let calendar = Calendar.current
        guard let interval = calendar.dateInterval(of: .month, for: date) else { return [:] }
        let monthEntries = try entries(from: interval.start, to: interval.end, limit: 1000)

        var scoresByDay: [Date: [Int]] = [:]
        for entry in monthEntries {
            let day = calendar.startOfDay(for: entry.entryDate)
            scoresByDay[day, default: []].append(entry.moodScore)
        }

        return scoresByDay.mapValues { scores in
            let total = scores.reduce(0, +)
            let average = total / scores.count
            return min(max(average, 1), 5)
        }
    }

    func deleteAll() throws {
        do {
            try context.delete(model: MoodEntry.self)
            try RepositoryHelpers.save(context, contextLabel: "MoodEntry.deleteAll")
        } catch {
            throw AppError.persistence(error, context: "MoodEntry.deleteAll")
        }
    }

    // MARK: - Private

    private func entry(withID id: UUID) throws -> MoodEntry? {
        let targetID = id
        var descriptor = FetchDescriptor<MoodEntry>(
            predicate: #Predicate { $0.id == targetID }
        )
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }
}
