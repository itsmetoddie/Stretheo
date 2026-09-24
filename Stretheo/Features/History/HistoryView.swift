//
//  HistoryView.swift
//  Stretheo
//

import OSLog
import SwiftData
import SwiftUI

struct HistoryView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Bindable var viewModel: HistoryViewModel
    @State private var insights: [Insight] = []

    private var activeRange: (start: Date, end: Date) {
        viewModel.activeDateRange
    }

    var body: some View {
        ZStack {
            Color(.systemBackground)
                .ignoresSafeArea()

            HistoryPeriodScrollContent(
                rangeStart: activeRange.start,
                rangeEnd: activeRange.end,
                viewModel: viewModel,
                colorScheme: colorScheme,
                insights: $insights
            )
        }
        .stretheoTabNavigation(title: String(localized: "tab.history"))
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    Task {
                        await viewModel.refresh(colorScheme: colorScheme)
                    }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .accessibilityLabel(String(localized: "accessibility.history.refresh"))
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                exportMenu
            }
        }
        .overlay {
            if viewModel.isLoading {
                ProgressView()
                    .controlSize(.large)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                    .background(AppColors.tertiarySystemFill.opacity(0.5))
                    .allowsHitTesting(false)
            }
        }
        .errorBanner(viewModel.errorMessage, isPresented: $viewModel.showError)
        .task(id: viewModel.historyLoadID) {
            StretheoLog.rangeSwitch.debug(
                "RANGE_SWITCH: HistoryView .task loadHistory start loadID=\(viewModel.historyLoadID, privacy: .public)"
            )
            let started = CFAbsoluteTimeGetCurrent()
            await viewModel.loadHistory(for: viewModel.historyLoadID, colorScheme: colorScheme)
            let elapsedMs = (CFAbsoluteTimeGetCurrent() - started) * 1000
            StretheoLog.rangeSwitch.debug(
                "RANGE_SWITCH: HistoryView .task loadHistory completed loadID=\(viewModel.historyLoadID, privacy: .public) elapsedMs=\(elapsedMs, privacy: .public)"
            )
        }
        .onChange(of: colorScheme) { _, scheme in
            viewModel.refreshCalendarColors(colorScheme: scheme)
        }
        .onDisappear {
            viewModel.cancelPendingWork()
        }
        .sheet(isPresented: $viewModel.showExportSheet, onDismiss: {
            viewModel.cleanupExportFile()
        }) {
            if let url = viewModel.exportURL {
                ShareSheet(items: [url])
            }
        }
    }

    private var exportMenu: some View {
        Menu {
            Button(String(localized: "export.pdf")) { viewModel.export(type: .pdf) }
            Button(String(localized: "export.csv")) { viewModel.export(type: .csv) }
        } label: {
            Image(systemName: "square.and.arrow.up")
        }
        .accessibilityLabel(String(localized: "accessibility.history.export"))
    }
}

// MARK: - Period-scoped stress query

private struct HistoryPeriodScrollContent: View {
    let rangeStart: Date
    let rangeEnd: Date
    @Bindable var viewModel: HistoryViewModel
    let colorScheme: ColorScheme
    @Binding var insights: [Insight]
    @Environment(\.modelContext) private var modelContext

    @Query private var insightMeasurements: [StressMeasurement]
    @Query private var insightSnapshots: [HealthSnapshot]
    @Query private var insightMoods: [MoodEntry]

    @Query private var moodEntries: [MoodEntry]

    @State private var insightsReady = false
    @State private var chartPoints: [StressChartPoint] = []
    @State private var isChartLoading = false
    @State private var historyCheckInRange: CheckInRange = .today
    @State private var cachedHistoryCheckIns: [StressMeasurement] = []
    @State private var moodCalendarByDayCache: [Date: Int] = [:]
    @State private var moodCalendarFillByDayCache: [Date: Color] = [:]

    @Query(sort: \StressMeasurement.measuredAt, order: .reverse)
    private var allCheckInMeasurements: [StressMeasurement]

    init(
        rangeStart: Date,
        rangeEnd: Date,
        viewModel: HistoryViewModel,
        colorScheme: ColorScheme,
        insights: Binding<[Insight]>
    ) {
        self.rangeStart = rangeStart
        self.rangeEnd = rangeEnd
        self.colorScheme = colorScheme
        _viewModel = Bindable(wrappedValue: viewModel)
        _insights = insights

        let insightCutoff = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        var measurementDescriptor = FetchDescriptor<StressMeasurement>(
            predicate: #Predicate { $0.measuredAt >= insightCutoff },
            sortBy: [SortDescriptor(\StressMeasurement.measuredAt, order: .forward)]
        )
        measurementDescriptor.fetchLimit = 5_000
        _insightMeasurements = Query(measurementDescriptor)

        var snapshotDescriptor = FetchDescriptor<HealthSnapshot>(
            predicate: #Predicate { $0.recordedAt >= insightCutoff },
            sortBy: [SortDescriptor(\HealthSnapshot.recordedAt, order: .forward)]
        )
        snapshotDescriptor.fetchLimit = 5_000
        _insightSnapshots = Query(snapshotDescriptor)

        var moodDescriptor = FetchDescriptor<MoodEntry>(
            predicate: #Predicate { $0.entryDate >= insightCutoff },
            sortBy: [SortDescriptor(\MoodEntry.entryDate, order: .forward)]
        )
        moodDescriptor.fetchLimit = 5_000
        _insightMoods = Query(moodDescriptor)

        var calendarMoodDescriptor = FetchDescriptor<MoodEntry>(
            sortBy: [SortDescriptor(\MoodEntry.entryDate, order: .reverse)]
        )
        calendarMoodDescriptor.fetchLimit = 10_000
        _moodEntries = Query(calendarMoodDescriptor)

        var checkInDescriptor = FetchDescriptor<StressMeasurement>(
            sortBy: [SortDescriptor(\StressMeasurement.measuredAt, order: .reverse)]
        )
        checkInDescriptor.fetchLimit = 1_000
        _allCheckInMeasurements = Query(checkInDescriptor)
    }

    private var moodCalendarByDay: [Date: Int] { moodCalendarByDayCache }

    private var moodCalendarFillByDay: [Date: Color] { moodCalendarFillByDayCache }

    private var insightTaskKey: String {
        let measurementTail = insightMeasurements.last?.id.uuidString ?? "none"
        let moodTail = insightMoods.last?.id.uuidString ?? "none"
        return "\(insightMeasurements.count)-\(measurementTail)-\(insightSnapshots.count)-\(insightMoods.count)-\(moodTail)"
    }

    private var historyFilteredMeasurements: [StressMeasurement] {
        cachedHistoryCheckIns
    }

    private func refreshHistoryCheckInsCache() {
        cachedHistoryCheckIns = Self.filterCheckIns(allCheckInMeasurements, range: historyCheckInRange)
    }

    private func refreshMoodCalendarCache() {
        moodCalendarByDayCache = Self.moodScoresByDay(
            from: moodEntries,
            monthContaining: viewModel.displayedCalendarMonth
        )
        moodCalendarFillByDayCache = Self.moodFillByDay(
            scoresByDay: moodCalendarByDayCache,
            monthContaining: viewModel.displayedCalendarMonth,
            colorScheme: colorScheme
        )
    }

    private static func filterCheckIns(
        _ measurements: [StressMeasurement],
        range: CheckInRange
    ) -> [StressMeasurement] {
        let calendar = Calendar.current
        let now = Date()

        switch range {
        case .today:
            return measurements.filter { calendar.isDateInToday($0.measuredAt) }
        case .week:
            guard let weekAgo = calendar.date(byAdding: .day, value: -7, to: now) else {
                return measurements
            }
            return measurements.filter { $0.measuredAt >= weekAgo }
        case .month:
            guard let monthAgo = calendar.date(byAdding: .month, value: -1, to: now) else {
                return measurements
            }
            return measurements.filter { $0.measuredAt >= monthAgo }
        case .all:
            return measurements
        }
    }

    private var historyCheckInRecordCountLabel: String {
        let count = historyFilteredMeasurements.count
        if count == 1 {
            return String(localized: "checkins.count.one")
        }
        return String(format: String(localized: "checkins.count.many"), count)
    }

    /// Drives background chart reload when period or active date range changes.
    private var chartLoadToken: String {
        "\(viewModel.period.rawValue)-\(rangeStart.timeIntervalSince1970)-\(rangeEnd.timeIntervalSince1970)"
    }

    private func loadChartData() async {
        StretheoLog.historyPerf.debug(
            "loadChartData task entry token=\(chartLoadToken, privacy: .public) at \(Date(), privacy: .public)"
        )
        defer {
            StretheoLog.historyPerf.debug(
                "loadChartData task exit token=\(chartLoadToken, privacy: .public) at \(Date(), privacy: .public)"
            )
        }

        isChartLoading = true
        defer { isChartLoading = false }
        do {
            let range = DateInterval(start: rangeStart, end: rangeEnd)
            StretheoLog.history.debug(
                "loadData ENTER range=\(range, privacy: .public) thread=main site=HistoryView.loadChartData.await"
            )
            chartPoints = try await viewModel.loadChartData(
                rangeStart: rangeStart,
                rangeEnd: rangeEnd
            )
            StretheoLog.history.debug(
                "loadData EXIT range=\(range, privacy: .public) site=HistoryView.loadChartData.await count=\(chartPoints.count, privacy: .public)"
            )
        } catch {
            StretheoLog.history.error("Chart load failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(showsIndicators: false) {
                VStack(spacing: AppSpacing.sm) {
                    VStack(spacing: AppSpacing.sm) {
                        TabScrollSubtitle(text: String(localized: "history.subtitle"))

                        LazyVStack(spacing: AppSpacing.sm) {
                            TrendsInsightCard(insights: insights, isReady: insightsReady)
                                .id("insights")
                                .animatedCard(index: 0)

                            StressHistoryChartCard(
                                viewModel: viewModel,
                                points: chartPoints,
                                rangeStart: rangeStart,
                                rangeEnd: rangeEnd,
                                chartDrawn: !chartPoints.isEmpty,
                                isChartLoading: isChartLoading
                            )
                            .id("chart")
                            .animatedCard(index: 1)

                            MoodCalendarView(
                                displayedMonth: $viewModel.displayedCalendarMonth,
                                moodByDay: moodCalendarByDay,
                                moodFillByDay: moodCalendarFillByDay,
                                onMonthChange: { viewModel.displayedMonthDidChange(to: $0, colorScheme: colorScheme) }
                            )
                            .opacity(viewModel.isLoading ? 0.6 : 1)
                        }
                    }
                    .padding(.horizontal, AppSpacing.screenHorizontal)

                    Color.clear
                        .frame(height: 0)
                        .id("checkInsSection")

                    checkInsSection
                        .padding(.horizontal, AppSpacing.screenHorizontal)
                }
                .padding(.bottom, AppSpacing.tabBarClearance)
            }
            .onReceive(NotificationCenter.default.publisher(for: .scrollToCheckIns)) { _ in
                withAnimation(.easeInOut(duration: 0.5)) {
                    proxy.scrollTo("checkInsSection", anchor: .top)
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color(.systemBackground))
        .onAppear {
            refreshHistoryCheckInsCache()
            refreshMoodCalendarCache()
        }
        .onChange(of: historyCheckInRange) { _, _ in
            refreshHistoryCheckInsCache()
        }
        .onChange(of: allCheckInMeasurements.count) { _, _ in
            refreshHistoryCheckInsCache()
        }
        .onChange(of: moodEntries.count) { _, _ in
            refreshMoodCalendarCache()
        }
        .onChange(of: viewModel.displayedCalendarMonth) { _, _ in
            refreshMoodCalendarCache()
        }
        .onChange(of: colorScheme) { _, _ in
            refreshMoodCalendarCache()
        }
        .task(id: chartLoadToken) {
            await loadChartData()
        }
        .task(id: insightTaskKey) {
            try? await Task.sleep(for: .milliseconds(50))
            await recomputeInsights()
        }
    }

    private var checkInsSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionHeaderView(
                systemImage: "waveform.path.ecg",
                title: String(localized: "history.checkins.title")
            )
            .animatedCard(index: 2)

            Picker(String(localized: "checkins.range.label"), selection: $historyCheckInRange) {
                ForEach(CheckInRange.allCases) { range in
                    Text(range.title).tag(range)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, AppSpacing.md)
            .padding(.vertical, 10)

            HStack {
                Text(historyCheckInRecordCountLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding(.horizontal, AppSpacing.md)
            .padding(.bottom, 4)

            if historyFilteredMeasurements.isEmpty {
                CardInlineEmptyState(
                    systemImage: "waveform.path.ecg",
                    title: String(localized: "checkins.empty.title"),
                    hint: String(localized: "checkins.empty.message")
                )
                .homeScreenCard(padding: AppSpacing.md)
                .animatedCard(index: 3)
            } else {
                LazyVStack(spacing: AppSpacing.xs) {
                    ForEach(Array(historyFilteredMeasurements.enumerated()), id: \.element.id) { index, measurement in
                        RecentCheckInRow(measurement: measurement)
                            .animatedCard(index: 3 + index)
                            .contextMenu {
                                Button(role: .destructive) {
                                    HapticFeedback.impact(.medium)
                                    deleteMeasurement(measurement)
                                } label: {
                                    Label(String(localized: "common.delete"), systemImage: "trash")
                                }
                            }
                    }
                }
                .homeScreenCard(padding: AppSpacing.sm, elevated: false)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: historyCheckInRange)
    }

    private func deleteMeasurement(_ measurement: StressMeasurement) {
        modelContext.delete(measurement)
        try? modelContext.save()
    }

    private static func moodScoresByDay(from entries: [MoodEntry], monthContaining month: Date) -> [Date: Int] {
        let calendar = Calendar.current
        guard let interval = calendar.dateInterval(of: .month, for: month) else { return [:] }

        let monthEntries = entries.filter { $0.entryDate >= interval.start && $0.entryDate < interval.end }
        var entriesByDay: [Date: [MoodEntry]] = [:]
        for entry in monthEntries {
            let day = calendar.startOfDay(for: entry.entryDate)
            entriesByDay[day, default: []].append(entry)
        }

        var scores: [Date: Int] = [:]
        var day = calendar.startOfDay(for: interval.start)
        while day < interval.end {
            if let dominant = dominantMoodScore(for: entriesByDay[day] ?? []) {
                scores[day] = dominant
            }
            guard let nextDay = calendar.date(byAdding: .day, value: 1, to: day) else { break }
            day = nextDay
        }
        return scores
    }

    private static func moodFillByDay(
        scoresByDay: [Date: Int],
        monthContaining month: Date,
        colorScheme: ColorScheme
    ) -> [Date: Color] {
        let calendar = Calendar.current
        guard let interval = calendar.dateInterval(of: .month, for: month) else { return [:] }

        var fills: [Date: Color] = [:]
        var day = calendar.startOfDay(for: interval.start)
        while day < interval.end {
            if let score = scoresByDay[day] {
                fills[day] = MoodColors.moodColor(for: score).opacity(colorScheme == .dark ? 0.5 : 0.35)
            } else {
                fills[day] = Color(.systemGray5)
            }
            guard let nextDay = calendar.date(byAdding: .day, value: 1, to: day) else { break }
            day = nextDay
        }
        return fills
    }

    private static func dominantMoodScore(for entries: [MoodEntry]) -> Int? {
        guard !entries.isEmpty else { return nil }
        let total = entries.map(\.moodScore).reduce(0, +)
        let average = total / entries.count
        return min(max(average, 1), 5)
    }

    private func recomputeInsights() async {
        let input = InsightEngineInput(
            measurements: insightMeasurements.map {
                InsightEngineInput.Measurement(stressLevel: $0.stressLevel, measuredAt: $0.measuredAt)
            },
            snapshots: insightSnapshots.map {
                InsightEngineInput.Snapshot(
                    sleepDuration: $0.sleepDuration,
                    hrv: $0.hrv,
                    recordedAt: $0.recordedAt
                )
            },
            moods: insightMoods.map {
                InsightEngineInput.Mood(moodScore: $0.moodScore, entryDate: $0.entryDate)
            },
            referenceDate: Date()
        )

        let result = await Task.detached(priority: .userInitiated) {
            InsightEngine.compute(input: input)
        }.value

        insights = result
        insightsReady = true
    }
}
