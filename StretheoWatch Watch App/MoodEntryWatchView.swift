//
//  MoodEntryWatchView.swift
//  StretheoWatch
//

import SwiftData
import SwiftUI
import WatchKit

struct MoodEntryWatchView: View {
    @Environment(\.modelContext) private var modelContext

    @State private var selectedScore: Int?
    @State private var saved = false
    @ScaledMetric(relativeTo: .largeTitle) private var confirmationIconSize: CGFloat = 40

    private let moods: [(score: Int, emoji: String, label: String, color: Color)] = [
        (5, "😊", "Great", Self.moodColor(for: 5)),
        (4, "🙂", "Good", Self.moodColor(for: 4)),
        (3, "😐", "Okay", Self.moodColor(for: 3)),
        (2, "😟", "Bad", Self.moodColor(for: 2)),
        (1, "😢", "Terrible", Self.moodColor(for: 1))
    ]

    var body: some View {
        NavigationStack {
            Group {
                if saved {
                    confirmationView
                } else {
                    moodList
                }
            }
            .navigationTitle("Mood")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var moodList: some View {
        List {
            ForEach(moods, id: \.score) { mood in
                Button {
                    selectedScore = mood.score
                    saveMood(score: mood.score)
                } label: {
                    HStack(spacing: 12) {
                        Text(mood.emoji)
                            .font(.title2)
                        Text(mood.label)
                            .font(.body)
                            .fontWeight(.medium)
                        Spacer()
                        if selectedScore == mood.score {
                            Image(systemName: "checkmark")
                                .foregroundStyle(mood.color)
                                .fontWeight(.semibold)
                        }
                    }
                    .padding(.vertical, 4)
                }
                .listRowBackground(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(selectedScore == mood.score ? mood.color.opacity(0.2) : Color.white.opacity(0.12))
                )
            }
        }
        .listStyle(.carousel)
        .dynamicTypeSize(.large ... .accessibility3)
    }

    private var confirmationView: some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: confirmationIconSize))
                .foregroundStyle(.green)
            Text("Mood Saved")
                .font(.headline)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                saved = false
                selectedScore = nil
            }
        }
    }

    private func saveMood(score: Int) {
        WKInterfaceDevice.current().play(.success)

        let moodWords = [5: "Great", 4: "Good", 3: "Okay", 2: "Bad", 1: "Terrible"]
        let word = moodWords[score]
        let entryDate = Date()

        let entry = MoodEntry(
            moodScore: score,
            moodWord: word,
            entryDate: entryDate,
            createdAt: entryDate
        )

        modelContext.insert(entry)
        try? modelContext.save()

        WatchConnectivityManager.shared.sendMoodEntry(score: score, word: word ?? "", date: entryDate)

        withAnimation(.easeInOut(duration: 0.2)) {
            saved = true
        }
    }

    /// Matches iPhone `MoodColors` palette.
    private static func moodColor(for score: Int) -> Color {
        switch score {
        case 1: .red
        case 2: .orange
        case 3: .yellow
        case 4: .green
        case 5: .mint
        default: .gray
        }
    }
}
