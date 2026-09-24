//
//  MoodView.swift
//  Stretheo
//

import SwiftData
import SwiftUI

struct MoodView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.modelContext) private var modelContext
    @Bindable var viewModel: MoodViewModel
    @Query private var moods: [MoodEntry]

    @State private var selectedDate = Calendar.current.startOfDay(for: Date())
    @State private var showDatePicker = false
    @AppStorage(AppSettingsKey.moodDatePickerDiscovered) private var hasDiscoveredDatePicker = false
    @State private var moodSaveConfirmed = false
    @State private var saveConfirmationScore: Int?
    @State private var moodCardScale: CGFloat = 1.0
    @State private var moodSaveTask: Task<Void, Never>?
    @State private var moodConfirmationResetTask: Task<Void, Never>?
    /// 0 = no draft score (SceneStorage cannot store `Int?`).
    @SceneStorage("mood.draft.score") private var draftScoreRaw = 0
    @SceneStorage("mood.draft.word") private var draftWord = ""
    private let sectionSpacing: CGFloat = AppSpacing.md

    init(viewModel: MoodViewModel) {
        _viewModel = Bindable(wrappedValue: viewModel)

        let calendar = Calendar.current
        let end = calendar.startOfDay(for: Date())
        let start = calendar.date(byAdding: .day, value: -30, to: end) ?? end
        var descriptor = FetchDescriptor<MoodEntry>(
            predicate: #Predicate { $0.entryDate >= start },
            sortBy: [SortDescriptor(\.entryDate, order: .reverse)]
        )
        descriptor.fetchLimit = 500
        _moods = Query(descriptor)
    }

    private var moodDateRange: ClosedRange<Date> {
        let calendar = Calendar.current
        let end = calendar.startOfDay(for: Date())
        let start = calendar.date(byAdding: .day, value: -30, to: end) ?? end
        return start...end
    }

    private var hasExistingEntryForSelectedDate: Bool {
        moods.contains { entry in
            Calendar.current.isDate(entry.entryDate, inSameDayAs: selectedDate)
        }
    }

    private var canSaveMood: Bool {
        viewModel.selectedScore != nil
    }

    private var todaysMoods: [MoodEntry] {
        moods
            .filter { Calendar.current.isDateInToday($0.entryDate) }
            .sorted { $0.entryDate > $1.entryDate }
    }

    private var saveButtonBackground: Color {
        if let score = viewModel.selectedScore ?? saveConfirmationScore {
            return MoodColors.moodColor(for: score)
        }
        return Color(.systemGray)
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: sectionSpacing) {
                TabScrollSubtitle(text: String(localized: "mood.subtitle"))

                rateYourMoodCard
                    .animatedCard(index: 0)
                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    todaysMoodsSection
                    MoodScaleLegend()
                        .animatedCard(index: 2 + min(todaysMoods.count, 5))
                }
            }
            .padding(.horizontal, AppSpacing.screenHorizontal)
            .padding(.bottom, AppSpacing.tabBarClearance)
        }
        .scrollDismissesKeyboard(.interactively)
        .dismissKeyboardOnTap()
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .stretheoTabNavigation(title: String(localized: "mood.title"))
        .errorBanner(viewModel.errorMessage, isPresented: $viewModel.showError)
        .onAppear {
            restoreMoodDraftIfNeeded()
        }
        .onChange(of: viewModel.selectedScore) { _, score in
            draftScoreRaw = score ?? 0
        }
        .onChange(of: viewModel.moodWord) { _, word in
            draftWord = word
        }
        .onDisappear {
            moodSaveTask?.cancel()
            moodConfirmationResetTask?.cancel()
            viewModel.cancelPendingWork()
        }
    }

    // MARK: - Date selection

    private var isSelectedDateToday: Bool {
        Calendar.current.isDateInToday(selectedDate)
    }

    private static let datePickerSpring = Animation.spring(response: 0.38, dampingFraction: 0.82)

    private var dateHeaderRow: some View {
        HStack(spacing: 8) {
            datePillButton

            if !hasDiscoveredDatePicker {
                Text(String(localized: "mood.date.hint"))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
                    .transition(.opacity)
            }

            Spacer(minLength: AppSpacing.sm)

            if !isSelectedDateToday {
                Button(String(localized: "mood.date.reset_today")) {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        selectedDate = Calendar.current.startOfDay(for: Date())
                        showDatePicker = false
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
        .animation(.easeOut(duration: 0.3), value: hasDiscoveredDatePicker)
    }

    private var datePillButton: some View {
        Button {
            hasDiscoveredDatePicker = true
            withAnimation(Self.datePickerSpring) {
                showDatePicker.toggle()
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: isSelectedDateToday ? "calendar" : "calendar.badge.checkmark")
                Text(
                    isSelectedDateToday
                        ? String(localized: "mood.date.today")
                        : selectedDate.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated))
                )
                Image(systemName: "chevron.down")
                    .font(.caption.weight(.semibold))
                    .rotationEffect(.degrees(showDatePicker ? 180 : 0))
                    .animation(Self.datePickerSpring, value: showDatePicker)
            }
            .font(.subheadline)
            .fontWeight(.medium)
            .foregroundStyle(isSelectedDateToday ? Color.secondary : Color.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background {
                Capsule()
                    .fill(
                        isSelectedDateToday
                            ? Color(.secondarySystemGroupedBackground)
                            : Color.accentColor
                    )
            }
            .overlay {
                if isSelectedDateToday {
                    Capsule()
                        .strokeBorder(Color(.separator), lineWidth: 1)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(
            String(
                format: String(localized: "accessibility.mood.select_date"),
                selectedDate.formatted(.dateTime.month().day())
            )
        )
        .animation(.easeInOut(duration: 0.25), value: isSelectedDateToday)
    }

    // MARK: - Rate Your Mood

    private var rateYourMoodCard: some View {
        rateYourMoodCardContent
            .scaleEffect(moodCardScale)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: moodCardScale)
    }

    private var rateYourMoodCardContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionHeaderView(
                systemImage: "face.smiling",
                title: String(localized: "mood.rate.title")
            )

            VStack(alignment: .leading, spacing: AppSpacing.md) {
                dateHeaderRow

                if showDatePicker {
                    HStack {
                        DatePicker(
                            "",
                            selection: $selectedDate,
                            in: moodDateRange,
                            displayedComponents: .date
                        )
                        .datePickerStyle(.compact)
                        .labelsHidden()
                        .padding(.horizontal, AppSpacing.md)
                        .padding(.vertical, AppSpacing.xs)

                        Spacer()

                        Button(String(localized: "Done")) {
                            selectedDate = Calendar.current.startOfDay(for: selectedDate)
                            withAnimation(Self.datePickerSpring) {
                                showDatePicker = false
                                hasDiscoveredDatePicker = true
                            }
                        }
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(Color.accentColor)
                        .padding(.trailing, AppSpacing.md)
                    }
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }

                MoodPickerView(
                    selectedScore: viewModel.selectedScore,
                    onSelect: viewModel.selectScore,
                    reduceMotion: reduceMotion
                )

                VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                    ZStack(alignment: .topLeading) {
                        TextEditor(text: $viewModel.moodWord)
                            .frame(height: 80)
                            .scrollContentBackground(.hidden)
                            .padding(8)
                            .foregroundStyle(AppColors.label)
                            .onChange(of: viewModel.moodWord) { _, newValue in
                                if newValue.count > viewModel.moodWordLimit {
                                    viewModel.moodWord = String(newValue.prefix(viewModel.moodWordLimit))
                                }
                            }

                        if viewModel.moodWord.isEmpty {
                            Text("Write something...")
                                .font(.body)
                                .foregroundStyle(.secondary)
                                .padding(12)
                                .allowsHitTesting(false)
                        }
                    }
                    .background(
                        Color(.tertiarySystemGroupedBackground),
                        in: RoundedRectangle(cornerRadius: AppRadius.pill, style: .continuous)
                    )

                    Text("\(viewModel.moodWordCount)/\(viewModel.moodWordLimit)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }

                if hasExistingEntryForSelectedDate {
                    Label("You already logged a mood for this day", systemImage: "exclamationmark.circle")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }

                moodSaveButton
            }
            .padding(.horizontal, AppSpacing.md)
            .padding(.bottom, AppSpacing.md)
        }
        .animation(Self.datePickerSpring, value: showDatePicker)
        .homeScreenCard(padding: 0)
    }

    private var moodSaveButton: some View {
        Button {
            saveMoodTapped()
        } label: {
            HStack(spacing: 8) {
                if moodSaveConfirmed {
                    Image(systemName: "checkmark")
                        .fontWeight(.semibold)
                        .transition(.scale.combined(with: .opacity))
                }
                Text(moodSaveConfirmed ? String(localized: "mood.save.saved") : String(localized: "mood.save"))
                    .fontWeight(.semibold)
                    .transition(.opacity)
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(saveButtonBackground)
            )
            .animation(.easeInOut(duration: 0.2), value: moodSaveConfirmed)
            .animation(.easeInOut(duration: 0.2), value: viewModel.selectedScore)
        }
        .buttonStyle(.plain)
        .disabled(viewModel.selectedScore == nil || moodSaveConfirmed)
        .accessibilityLabel(String(localized: "mood.save"))
    }

    // MARK: - Save Mood

    private func saveMoodTapped() {
        guard canSaveMood, !moodSaveConfirmed else { return }

        moodSaveTask?.cancel()
        moodSaveTask = Task {
            await performMoodSave()
        }
    }

    private func moodEntryDateForSave() -> Date {
        let calendar = Calendar.current
        if calendar.isDateInToday(selectedDate) {
            return Date()
        }
        var components = calendar.dateComponents([.year, .month, .day], from: selectedDate)
        components.hour = 12
        components.minute = 0
        return calendar.date(from: components) ?? selectedDate
    }

    private func performMoodSave() async {
        do {
            try await viewModel.saveMood(entryDate: moodEntryDateForSave())
            guard !Task.isCancelled else { return }

            clearMoodDraft()
            selectedDate = Calendar.current.startOfDay(for: Date())
            HapticFeedback.success()
            playMoodSaveConfirmation()
        } catch {
            await MainActor.run {
                moodSaveConfirmed = false
                saveConfirmationScore = nil
                moodCardScale = 1.0
            }
        }
    }

    private func restoreMoodDraftIfNeeded() {
        if draftScoreRaw > 0 {
            viewModel.selectedScore = draftScoreRaw
        }
        if !draftWord.isEmpty {
            viewModel.moodWord = draftWord
        }
    }

    private func clearMoodDraft() {
        draftScoreRaw = 0
        draftWord = ""
    }

    private func playMoodSaveConfirmation() {
        moodConfirmationResetTask?.cancel()
        saveConfirmationScore = viewModel.selectedScore

        withAnimation(.easeInOut(duration: 0.2)) {
            moodSaveConfirmed = true
        }

        if !reduceMotion {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                moodCardScale = 1.02
            }
            withAnimation(.easeOut(duration: 0.2).delay(0.15)) {
                moodCardScale = 1.0
            }
        }

        moodConfirmationResetTask = Task {
            try? await Task.sleep(for: .milliseconds(800))
            guard !Task.isCancelled else { return }
            await MainActor.run {
                withAnimation(.easeInOut(duration: 0.3)) {
                    viewModel.selectedScore = nil
                }
            }
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            await MainActor.run {
                moodSaveConfirmed = false
                saveConfirmationScore = nil
            }
        }
    }

    // MARK: - Today's Moods

    private var todaysMoodsSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            SectionHeaderView(
                systemImage: "clock",
                title: String(localized: "mood.today.title")
            )
            .animatedCard(index: 2)

            if todaysMoods.isEmpty {
                CardInlineEmptyState(
                    systemImage: "face.smiling",
                    title: String(localized: "mood.today.empty"),
                    hint: String(localized: "mood.today.empty.hint")
                )
                .homeScreenCard(padding: AppSpacing.md)
                .animatedCard(index: 3)
            } else {
                VStack(spacing: AppSpacing.xs) {
                    ForEach(Array(todaysMoods.enumerated()), id: \.element.id) { index, entry in
                        MoodTodayEntryRow(entry: entry)
                            .padding(.horizontal, AppSpacing.md)
                            .animatedCard(index: 3 + index)
                            .contextMenu {
                                Button(role: .destructive) {
                                    HapticFeedback.impact(.medium)
                                    deleteMoodEntry(entry)
                                } label: {
                                    Label(String(localized: "common.delete"), systemImage: "trash")
                                }
                            }

                        if index < todaysMoods.count - 1 {
                            Color(.separator)
                                .frame(height: 0.5)
                                .padding(.leading, 56)
                        }
                    }
                }
                .homeScreenCard(padding: 0, elevated: false)
            }
        }
    }

    private func deleteMoodEntry(_ entry: MoodEntry) {
        modelContext.delete(entry)
        try? modelContext.save()
    }
}

// MARK: - Today's mood row

private struct MoodTodayEntryRow: View {
    let entry: MoodEntry

    private var scaleEntry: MoodScaleEntry? {
        MoodScaleEntry.all.first(where: { $0.id == entry.moodScore })
    }

    var body: some View {
        HStack(spacing: AppSpacing.md) {
            Text(scaleEntry?.emoji ?? "😐")
                .font(.largeTitle)
                .drawingGroup()

            VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                Text(scaleEntry?.label ?? "")
                    .font(AppTypography.rowPrimary)
                    .foregroundStyle(AppColors.label)
                Text(RecordDateFormatting.formatted(entry.entryDate))
                    .font(AppTypography.metadata)
                    .foregroundStyle(AppColors.secondaryLabel)
            }

            Spacer(minLength: 0)

            ZStack {
                Circle()
                    .fill(MoodColors.moodColor(for: entry.moodScore).opacity(0.15))
                    .frame(width: 44, height: 44)

                Text("\(entry.moodScore)")
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                    .foregroundStyle(MoodColors.moodTextColor(for: entry.moodScore))
            }
        }
        .padding(.vertical, AppSpacing.sm)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(moodRowAccessibilityLabel)
    }

    private var moodRowAccessibilityLabel: String {
        let label = scaleEntry?.label ?? String(localized: "tab.mood")
        let when = entry.entryDate.formatted(.relative(presentation: .named))
        return String(
            format: String(localized: "accessibility.mood.row"),
            entry.moodScore,
            label,
            when
        )
    }
}
