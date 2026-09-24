//
//  HomeView.swift
//  Stretheo
//

import OSLog
import SwiftData
import SwiftUI

private struct HomeTodayMetrics {
    let average: Int
    let checkInCount: Int
    let sparklinePoints: [SparklinePoint]
    let lastMeasuredAt: Date?

    static let empty = HomeTodayMetrics(average: 0, checkInCount: 0, sparklinePoints: [], lastMeasuredAt: nil)

    static func compute(from measurements: [StressMeasurement]) -> HomeTodayMetrics {
        guard !measurements.isEmpty else { return .empty }
        let average = measurements.map(\.stressLevel).reduce(0, +) / measurements.count
        let sparklinePoints = measurements.map { measurement in
            SparklinePoint(
                id: measurement.id,
                date: measurement.measuredAt,
                value: Double(measurement.stressLevel)
            )
        }
        return HomeTodayMetrics(
            average: average,
            checkInCount: measurements.count,
            sparklinePoints: sparklinePoints,
            lastMeasuredAt: measurements.last?.measuredAt
        )
    }
}

struct HomeView: View {
    @Bindable var viewModel: HomeViewModel
    @Environment(AppRouter.self) private var router
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @Query private var todayStressMeasurements: [StressMeasurement]
    @Query private var recentStressMeasurements: [StressMeasurement]
    @Query private var unreadNotifications: [NotificationLog]

    @State private var showNotificationHistory = false

    @State private var isMeasuring = false
    @State private var measureButtonState: MeasureButtonState = .idle
    @State private var stressSaveConfirmed = false
    @State private var stressCardScale: CGFloat = 1.0
    @State private var measureStressTask: Task<Void, Never>?
    @State private var stressConfirmationResetTask: Task<Void, Never>?

    private static let recentCheckInsLimit = 5

    init(viewModel: HomeViewModel) {
        _viewModel = Bindable(wrappedValue: viewModel)

        let calendar = Calendar.current
        let twoWeeksAgo = calendar.date(byAdding: .day, value: -14, to: Date()) ?? calendar.startOfDay(for: Date())
        let todayStart = calendar.startOfDay(for: Date())
        let tomorrowStart = calendar.date(byAdding: .day, value: 1, to: todayStart) ?? todayStart.addingTimeInterval(86_400)

        var todayDescriptor = FetchDescriptor<StressMeasurement>(
            predicate: #Predicate { $0.measuredAt >= todayStart && $0.measuredAt < tomorrowStart },
            sortBy: [SortDescriptor(\StressMeasurement.measuredAt, order: .forward)]
        )
        todayDescriptor.fetchLimit = 100

        var recentDescriptor = FetchDescriptor<StressMeasurement>(
            predicate: #Predicate { $0.measuredAt >= twoWeeksAgo },
            sortBy: [SortDescriptor(\StressMeasurement.measuredAt, order: .reverse)]
        )
        recentDescriptor.fetchLimit = Self.recentCheckInsLimit

        _todayStressMeasurements = Query(todayDescriptor)
        _recentStressMeasurements = Query(recentDescriptor)

        let unreadDescriptor = FetchDescriptor<NotificationLog>(
            predicate: #Predicate { !$0.isRead },
            sortBy: [SortDescriptor(\NotificationLog.sentAt, order: .reverse)]
        )
        _unreadNotifications = Query(unreadDescriptor)
    }

    private var unreadCount: Int { unreadNotifications.count }

    private var todayMetrics: HomeTodayMetrics {
        HomeTodayMetrics.compute(from: todayStressMeasurements)
    }

    private var latestMeasurement: StressMeasurement? {
        todayStressMeasurements.last ?? recentStressMeasurements.first
    }

    private var gaugeProgress: Double {
        Double(latestMeasurement?.stressLevel ?? 0) / 100.0
    }

    private var recentCheckInsSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            if recentStressMeasurements.isEmpty {
                SectionHeaderView(
                    systemImage: "clock.arrow.circlepath",
                    title: String(localized: "home.recent.title")
                )
                .animatedCard(index: 3)
            } else {
                SectionHeaderView(
                    systemImage: "clock.arrow.circlepath",
                    title: String(localized: "home.recent.title")
                ) {
                    Button {
                        router.selectedTab = .history
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                            NotificationCenter.default.post(name: .scrollToCheckIns, object: nil)
                        }
                    } label: {
                        Text(String(localized: "home.recent.see_all"))
                            .font(.subheadline)
                            .foregroundStyle(Color.accentColor)
                    }
                }
                .animatedCard(index: 3)
            }

            if recentStressMeasurements.isEmpty {
                CardInlineEmptyState(
                    systemImage: "list.bullet.clipboard",
                    title: String(localized: "home.recent.empty")
                )
                .homeScreenCard(padding: AppSpacing.sm, elevated: false)
                .animatedCard(index: 4)
            } else {
                LazyVStack(spacing: AppSpacing.xs) {
                    ForEach(Array(recentStressMeasurements.prefix(Self.recentCheckInsLimit).enumerated()), id: \.element.id) { index, measurement in
                        RecentCheckInRow(measurement: measurement)
                            .animatedCard(index: 4 + index)
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
    }

    var body: some View {
        applyHomeLifecycle(
            ZStack {
                homeScrollView
                    .blur(radius: showNotificationHistory ? 3.0 : 0.0)
                    .overlay {
                        if showNotificationHistory {
                            Color.black
                                .opacity(0.15)
                                .ignoresSafeArea()
                                .allowsHitTesting(false)
                        }
                    }
                    .animation(.easeInOut(duration: 0.3), value: showNotificationHistory)
            }
            .stretheoTabNavigation(title: String(localized: "home.title"))
            .toolbar { homeNotificationBellToolbar }
            .modifier(HomeNavigationBarToolbarBackground(isNotificationHistoryPresented: showNotificationHistory))
            .sheet(isPresented: $showNotificationHistory) {
                NotificationHistoryView()
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
                    .presentationCornerRadius(LiquidGlassMetrics.sheetCornerRadius)
                    .presentationBackground {
                        LiquidGlassSheetBackground()
                    }
            }
            .errorBanner(viewModel.errorMessage, isPresented: $viewModel.showError) {
                viewModel.dismissError()
            }
        )
    }

    @ToolbarContentBuilder
    private var homeNotificationBellToolbar: some ToolbarContent {
        ToolbarItem(placement: .navigationBarTrailing) {
            Button {
                showNotificationHistory = true
            } label: {
                Image(systemName: unreadCount > 0 ? "bell.badge.fill" : "bell")
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(
                        unreadCount > 0 ? Color.red : Color.secondary,
                        unreadCount > 0 ? Color.accentColor : Color.secondary
                    )
                    .symbolEffect(.bounce, value: unreadCount)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(
                unreadCount > 0
                    ? String(format: String(localized: "accessibility.notifications.unread"), unreadCount)
                    : String(localized: "accessibility.notifications")
            )
        }
    }

    @ViewBuilder
    private var homeScrollView: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                TabScrollSubtitle(text: String(localized: "home.subtitle"))

                TodayAverageCard(
                    average: todayMetrics.average,
                    checkInCount: todayMetrics.checkInCount,
                    category: StressCategory.from(level: todayMetrics.average),
                    sparklinePoints: todayMetrics.sparklinePoints,
                    lastMeasuredAt: todayMetrics.lastMeasuredAt
                )
                .animatedCard(index: 0)

                // No .animatedCard on Stress Analysis (cold-launch fix). Score text animation rules: see StressGaugeView.
                HomeStressGaugeSection(
                    gauge: viewModel.gaugeDisplay,
                    stressLevel: latestMeasurement?.stressLevel,
                    measurementID: latestMeasurement?.id,
                    gaugeProgress: gaugeProgress,
                    isMeasuring: isMeasuring,
                    measureButtonState: $measureButtonState,
                    stressSaveConfirmed: $stressSaveConfirmed,
                    stressCardScale: $stressCardScale,
                    reduceMotion: reduceMotion,
                    onMeasure: { beginMeasureNow() }
                )

                BreathingExerciseCard(
                    selectedTechniqueIndex: $viewModel.breathingTechniqueIndex,
                    onStart: { viewModel.startBreathingSession() }
                )
                .animatedCard(index: 2)

                recentCheckInsSection

                if let last = todayMetrics.lastMeasuredAt ?? viewModel.gaugeDisplay.lastMeasuredAt {
                    Text(
                        String(
                            format: String(localized: "home.last_measured"),
                            last.formatted(date: .omitted, time: .shortened)
                        )
                    )
                    .font(AppTypography.metadata)
                    .foregroundStyle(AppColors.secondaryLabel)
                    .frame(maxWidth: .infinity, alignment: .center)
                }
            }
            .padding(.horizontal, AppSpacing.screenHorizontal)
            .padding(.bottom, AppSpacing.tabBarClearance)
        }
        .refreshable {
            await viewModel.refresh()
        }
    }

    @ViewBuilder
    private func applyHomeLifecycle<Content: View>(_ content: Content) -> some View {
        content
            .task {
                syncGaugeFromQuery(animated: false)
            }
            .onReceive(NotificationCenter.default.publisher(for: .newMeasurementSaved)) { notification in
                let userInfo = notification.userInfo ?? [:]
                if let level = userInfo[StressNotificationUserInfoKey.level] as? Int {
                    viewModel.updateGaugeLevel(level)
                } else if let level = userInfo[StressNotificationUserInfoKey.level] as? NSNumber {
                    viewModel.updateGaugeLevel(level.intValue)
                }
                syncGaugeFromQuery(animated: false)
            }
            .onDisappear {
                measureStressTask?.cancel()
                measureStressTask = nil
                stressConfirmationResetTask?.cancel()
                resetMeasureButtonState()
                stressSaveConfirmed = false
                viewModel.cancelPendingWork()
            }
    }

    private func syncGaugeFromQuery(animated: Bool = false) {
        if let latestToday = todayStressMeasurements.last {
            viewModel.syncGauge(from: latestToday, animated: animated)
        } else if let latest = recentStressMeasurements.first {
            viewModel.syncGauge(from: latest, animated: animated)
        }
    }

    // MARK: - Measure Now

    private func beginMeasureNow() {
        guard measureButtonState == .idle, !stressSaveConfirmed, !isMeasuring else { return }

        StretheoLog.measureStress.debug("MEASURE_NOW: tapped, starting measurement")
        startMeasuringState()

        measureStressTask?.cancel()
        measureStressTask = Task { @MainActor in
            await runMeasureFlow()
        }
    }

    private func startMeasuringState() {
        HapticFeedback.light()
        isMeasuring = true
        if !reduceMotion {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                measureButtonState = .measuring
            }
        } else {
            measureButtonState = .measuring
        }
    }

    private func runMeasureFlow() async {
        defer {
            resetMeasureButtonState()
            StretheoLog.measureStress.debug("MEASURE_NOW: reset measuring state (defer)")
        }

        StretheoLog.measureStress.debug("MEASURE_NOW: runMeasureFlow started")
        let succeeded = await viewModel.measureStress()

        guard !Task.isCancelled else {
            StretheoLog.measureStress.debug("MEASURE_NOW: task cancelled after measureStress")
            return
        }

        StretheoLog.measureStress.debug("MEASURE_NOW: runMeasureFlow measureStress returned succeeded=\(succeeded, privacy: .public)")

        if succeeded, viewModel.gaugeDisplay.hasStressMeasurement {
            playStressSaveConfirmation()
        }
    }

    private func resetMeasureButtonState() {
        isMeasuring = false
        measureButtonState = .idle
    }

    private func playStressSaveConfirmation() {
        stressConfirmationResetTask?.cancel()

        if reduceMotion {
            stressSaveConfirmed = true
            stressConfirmationResetTask = scheduleStressConfirmationReset()
            return
        }

        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
            stressSaveConfirmed = true
            stressCardScale = 1.02
        }
        withAnimation(.easeOut(duration: 0.2).delay(0.15)) {
            stressCardScale = 1.0
        }

        stressConfirmationResetTask = scheduleStressConfirmationReset()
    }

    private func scheduleStressConfirmationReset() -> Task<Void, Never> {
        // CLEANED: stored Task so confirmation reset is cancelled when the view disappears
        Task {
            try? await Task.sleep(for: .milliseconds(600))
            guard !Task.isCancelled else { return }
            withAnimation(.easeInOut(duration: 0.2)) {
                stressSaveConfirmed = false
            }
        }
    }

    private func deleteMeasurement(_ measurement: StressMeasurement) {
        modelContext.delete(measurement)
        try? modelContext.save()
    }
}

// MARK: - Gauge section (isolates high-frequency gauge updates)

private struct HomeStressGaugeSection: View {
    @Bindable var gauge: HomeGaugeDisplayState
    let stressLevel: Int?
    let measurementID: UUID?
    let gaugeProgress: Double
    let isMeasuring: Bool
    @Binding var measureButtonState: MeasureButtonState
    @Binding var stressSaveConfirmed: Bool
    @Binding var stressCardScale: CGFloat
    let reduceMotion: Bool
    let onMeasure: () -> Void

    var body: some View {
        StressAnalysisCard(
            level: gauge.displayStressLevel,
            stressLevel: stressLevel,
            category: gauge.currentCategory,
            hint: gauge.analysisHint,
            hasMeasurement: gauge.hasStressMeasurement,
            isMeasuring: isMeasuring,
            measureButtonState: $measureButtonState,
            stressSaveConfirmed: $stressSaveConfirmed,
            stressCardScale: $stressCardScale,
            gaugeProgressValue: gaugeProgress,
            reduceMotion: reduceMotion,
            measurementID: measurementID,
            onMeasure: onMeasure
        )
    }
}

/// Applies material nav bar background only while notification history is presented.
/// Default bar appearance (matching other tabs) keeps the navigation subtitle legible.
private struct HomeNavigationBarToolbarBackground: ViewModifier {
    let isNotificationHistoryPresented: Bool

    func body(content: Content) -> some View {
        if isNotificationHistoryPresented {
            content.toolbarBackground(.ultraThinMaterial, for: .navigationBar)
        } else {
            content
        }
    }
}
