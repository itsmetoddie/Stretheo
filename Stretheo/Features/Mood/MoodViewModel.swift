//
//  MoodViewModel.swift
//  Stretheo
//

import Foundation
import SwiftUI

@MainActor
@Observable
final class MoodViewModel {
    private let dependencies: AppDependencies
    private var loadTask: Task<Void, Never>?
    private var hasLoaded = false

    var selectedScore: Int?
    var moodWord: String = ""
    var todayEntries: [MoodEntry] = []
    private(set) var sortedTodayEntries: [MoodEntry] = []
    var errorMessage: String?
    var showError = false

    var moodWordCount: Int { moodWord.count }
    var moodWordLimit: Int { DataValidation.moodWordMaxLength }

    init(dependencies: AppDependencies) {
        self.dependencies = dependencies
        scheduleInitialLoad()
    }

    func loadIfNeeded() async {
        guard !hasLoaded else { return }
        hasLoaded = true
        await loadData(animated: false)
    }

    func reload(animated: Bool = false) {
        loadTask?.cancel()
        loadTask = Task { await loadData(animated: animated) }
    }

    func cancelPendingWork() {
        loadTask?.cancel()
    }

    func selectScore(_ score: Int) {
        if selectedScore == score {
            selectedScore = nil
        } else {
            selectedScore = score
        }
        HapticFeedback.light()
    }

    func saveMood(entryDate: Date) async throws {
        guard let score = selectedScore else { return }

        do {
            _ = try await dependencies.logMoodUseCase.execute(
                score: score,
                word: moodWord.isEmpty ? nil : moodWord,
                entryDate: entryDate
            )
            moodWord = ""
            await loadData(animated: true)
        } catch {
            errorMessage = error.localizedDescription
            showError = true
            throw error
        }
    }

    private func scheduleInitialLoad() {
        loadTask = Task { await loadIfNeeded() }
    }

    private func loadData(animated: Bool) async {
        do {
            let entries = try dependencies.moodRepository.todayEntries()
            let sorted = entries.sorted { $0.entryDate > $1.entryDate }
            if animated {
                let response = CalmAnimationTiming.reduceMotion ? 0 : 0.9
                withAnimation(.spring(response: response, dampingFraction: 0.85)) {
                    todayEntries = entries
                    sortedTodayEntries = sorted
                }
            } else {
                todayEntries = entries
                sortedTodayEntries = sorted
            }
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }
}
