//
//  SettingsView.swift
//  Stretheo
//

import AuthenticationServices
import OSLog
import PhotosUI
import SwiftData
import SwiftUI

struct SettingsView: View {
    @Bindable var viewModel: SettingsViewModel
    @Environment(AppSettingsStore.self) private var appSettings
    @Environment(AppRouter.self) private var router
    @Environment(\.appDependencies) private var dependencies
    @Environment(\.modelContext) private var modelContext
    @State private var photoItem: PhotosPickerItem?
    @State private var showExportOptions = false
    @State private var exportType: ExportType = .csv
    @State private var exportStart = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
    @State private var exportEnd = Date()
    @State private var showEditProfile = false
    @State private var cachedAvatarImage: UIImage?
    @State private var stressThreshold = Double(AppSettings.stressAlertThreshold)
    @AppStorage(AppSettingsKey.iCloudSyncEnabled) private var iCloudSyncEnabled = false
    @AppStorage(AppSettingsKey.moodReminderEnabled) private var moodReminderEnabled = false
    @AppStorage(AppSettingsKey.moodReminderTime) private var moodReminderTimeInterval = 0.0
    @State private var showICloudRestartAlert = false
    @State private var showICloudRestartBanner = false
    private let cardPadding: CGFloat = AppSpacing.md
    private let sectionSpacing: CGFloat = 20
    private let headerCardSpacing: CGFloat = 8
    private let rowVerticalPadding: CGFloat = AppSpacing.md
    private let avatarSize: CGFloat = 72
    private let profileAvatarGradient = LinearGradient(
        colors: [Color(hex: "6B4EFF"), Color(hex: "8B6FFF")],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    var body: some View {
        ZStack {
            Color(.systemBackground)
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                LazyVStack(alignment: .leading, spacing: sectionSpacing) {
                    TabScrollSubtitle(text: String(localized: "settings.subtitle"))

                    profileSection
                    healthMonitoringSection
                    notificationsSection
                    appearanceSection
                    dataPrivacySection
                    #if DEBUG
                    VStack(spacing: 12) {
                        Divider()

                        Text("Debug")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Button("Test Threshold Notification") {
                            Task {
                                let threshold = appSettings.stressAlertThreshold
                                await AppDependencies.shared.notificationManager.scheduleIfNeeded(level: threshold + 1)
                            }
                        }
                        .font(.caption)
                        .foregroundStyle(.orange)

                        Button("Reset Daily Notification Count") {
                            AppDependencies.shared.notificationManager.resetDailyCount()
                        }
                        .font(.caption)
                        .foregroundStyle(.orange)

                        Button("Reset Onboarding") {
                            AppSettings.hasCompletedOnboarding = false
                            router.appState = .onboarding
                        }
                        .font(.caption)
                        .foregroundStyle(.orange)

                        Button("Test Background Measurement") {
                            Task { await runDebugBackgroundMeasurement() }
                        }
                        .font(.caption)
                        .foregroundStyle(.orange)

                        Button("Generate Test Data (30 days)") {
                            Task {
                                await TestDataGenerator.generate(modelContext: modelContext)
                            }
                        }
                        .font(.caption)
                        .foregroundStyle(.orange)

                        Button("Clear All Test Data") {
                            Task {
                                await TestDataGenerator.clear(modelContext: modelContext)
                            }
                        }
                        .font(.caption)
                        .foregroundStyle(.red)

                        Text(
                            "Runs HealthKit read → algorithm → SwiftData save → notification gates in-app. " +
                            "Watch console for [DEBUG] logs."
                        )
                        .font(AppTypography.metadata)
                        .foregroundStyle(AppColors.secondaryLabel)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.top, 8)
                    #endif
                    versionFooter
                }
                .padding(.horizontal, cardPadding)
                .padding(.bottom, AppSpacing.tabBarClearance)
            }
            .scrollContentBackground(.hidden)
            .background(Color(.systemBackground))
            .scrollDismissesKeyboard(.interactively)
        }
        .dismissKeyboardOnTap()
        .stretheoTabNavigation(title: String(localized: "tab.settings"))
        .errorBanner(viewModel.errorMessage, isPresented: $viewModel.showError)
        .onAppear {
            if cachedAvatarImage == nil {
                cachedAvatarImage = viewModel.ensureAvatarLoaded(displayPointSize: 72)
            }
            if moodReminderTimeInterval <= 0 {
                moodReminderTimeInterval = AppSettings.moodReminderTime.timeIntervalSince1970
            }
        }
        .onChange(of: viewModel.avatarCacheRevision) { _, _ in
            cachedAvatarImage = nil
        }
        .onChange(of: moodReminderEnabled) { _, enabled in
            syncMoodReminderSchedule(enabled: enabled)
        }
        .onChange(of: moodReminderTimeInterval) { _, _ in
            guard moodReminderEnabled else { return }
            syncMoodReminderSchedule(enabled: true)
        }
        .task {
            await viewModel.reload()
            updateICloudRestartBanner()
        }
        .onChange(of: iCloudSyncEnabled) { _, _ in
            updateICloudRestartBanner()
        }
        .alert(
            String(localized: "icloud.sync.alert.title"),
            isPresented: $showICloudRestartAlert
        ) {
            Button(String(localized: "icloud.sync.alert.later"), role: .cancel) {
                showICloudRestartBanner = true
            }
            Button(String(localized: "icloud.sync.alert.restart")) {
                exit(0)
            }
        } message: {
            Text(String(localized: "icloud.sync.alert.message"))
        }
        .sheet(isPresented: $viewModel.showExportSheet, onDismiss: {
            viewModel.cleanupExportFile()
        }) {
            if let url = viewModel.exportURL {
                ShareSheet(items: [url])
            }
        }
        .sheet(isPresented: $showExportOptions) {
            exportOptionsSheet
        }
        .sheet(isPresented: $showEditProfile) {
            NavigationStack {
                EditProfileView(viewModel: viewModel)
            }
            .presentationDetents([.medium, .large])
        }
    }

    // MARK: - Sections

    private var profileSection: some View {
        settingsSection(
            title: String(localized: "settings.profile.section"),
            systemImage: "person.fill"
        ) {
            VStack(spacing: 0) {
                Button {
                    showEditProfile = true
                } label: {
                    HStack(alignment: .center, spacing: AppSpacing.md) {
                        profileAvatarWithCameraBadge

                        VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                            Text(displayName)
                                .font(.title3)
                                .fontWeight(.bold)
                                .foregroundStyle(.primary)

                            Text(emailDisplayValue)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        Spacer(minLength: AppSpacing.sm)

                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Color(.tertiaryLabel))
                    }
                    .frame(minHeight: AppSpacing.minTouchTarget)
                    .padding(.vertical, rowVerticalPadding)
                }
                .buttonStyle(.plain)

                if FeatureFlags.signInWithAppleEnabled, !viewModel.isSignedIn {
                    SignInWithAppleButton(.signIn) { request in
                        request.requestedScopes = [.fullName, .email]
                    } onCompletion: { result in
                        viewModel.processAppleSignIn(result)
                    }
                    .signInWithAppleButtonStyle(.black)
                    .frame(height: AppSpacing.minTouchTarget)
                    .frame(maxWidth: .infinity)
                    .padding(.top, AppSpacing.md)
                    .padding(.bottom, rowVerticalPadding)
                }
            }
        }
        .animatedCard(index: 0)
        .onChange(of: photoItem) { _, item in
            Task { @MainActor in
                guard let data = try? await item?.loadTransferable(type: Data.self),
                      let image = UIImage(data: data) else { return }
                try? ProfileStore.shared.saveAvatarImage(image)
                if let saved = ProfileStore.shared.loadAvatarImage() {
                    let display = saved.downsampledForDisplay(pointSize: 72)
                    cachedAvatarImage = display
                    viewModel.updateAvatarImage(display)
                }
            }
        }
    }

    private var healthMonitoringSection: some View {
        settingsSection(
            title: String(localized: "settings.health.section"),
            systemImage: "heart.fill"
        ) {
            permissionToggleRow(
                title: String(localized: "settings.health.toggle"),
                subtitle: String(localized: "settings.health.subtitle"),
                systemImage: "heart.fill",
                iconBackground: .red,
                isOn: healthBinding
            )
            .animatedCard(index: 1)
        }
    }

    private var notificationsSection: some View {
        settingsSection(
            title: String(localized: "settings.notifications.section"),
            systemImage: "bell.fill"
        ) {
            VStack(spacing: 0) {
                permissionToggleRow(
                    title: String(localized: "settings.notifications.toggle"),
                    subtitle: String(localized: "settings.notifications.subtitle"),
                    systemImage: "bell.fill",
                    iconBackground: .orange,
                    isOn: notificationsBinding
                )
                .animatedCard(index: 2)

                if AppSettings.notificationsEnabled {
                    settingsDivider(leading: SettingsRowIconMetrics.dividerLeadingInset)

                    NavigationLink {
                        QuietHoursSettingsView(viewModel: viewModel)
                    } label: {
                        iconNavigationRow(
                            title: String(localized: "settings.quiet.title"),
                            trailing: quietHoursLabel,
                            systemImage: "moon.fill",
                            iconBackground: Color(red: 0.3, green: 0.3, blue: 0.8)
                        )
                    }
                    .buttonStyle(.plain)
                    .animatedCard(index: 3)

                    settingsDivider(leading: SettingsRowIconMetrics.dividerLeadingInset)

                    stressAlertThresholdRow

                    settingsDivider(leading: SettingsRowIconMetrics.dividerLeadingInset)

                    moodReminderToggleRow
                        .animatedCard(index: 4)

                    if moodReminderEnabled {
                        settingsDivider(leading: SettingsRowIconMetrics.dividerLeadingInset)

                        moodReminderTimeRow
                    }
                }
            }
            .animation(.easeInOut(duration: 0.2), value: moodReminderEnabled)
        }
    }

    private var appearanceSection: some View {
        VStack(alignment: .leading, spacing: headerCardSpacing) {
            SectionHeaderView(
                systemImage: "paintbrush.fill",
                title: String(localized: "settings.appearance.mode")
            )
            appearancePickerContent
                .padding(cardPadding)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    Color(.secondarySystemGroupedBackground),
                    in: RoundedRectangle(cornerRadius: HomeScreenCardStyle.cornerRadius, style: .continuous)
                )
                .stretheoShadow(HomeScreenCardStyle.shadow)
        }
        .animatedCard(index: 7)
    }

    private var dataPrivacySection: some View {
        settingsSection(
            title: String(localized: "settings.privacy.section"),
            systemImage: "lock.fill"
        ) {
            VStack(spacing: 0) {
                iCloudSyncContent
                    .animatedCard(index: 5)

                settingsDivider(leading: SettingsRowIconMetrics.dividerLeadingInset)

                Button {
                    showExportOptions = true
                } label: {
                    iconNavigationRow(
                        title: String(localized: "settings.privacy.export_data"),
                        trailing: "",
                        systemImage: "square.and.arrow.up.fill",
                        iconBackground: Color(red: 0.2, green: 0.6, blue: 0.4)
                    )
                }
                .buttonStyle(.plain)
                .animatedCard(index: 6)

                settingsDivider(leading: SettingsRowIconMetrics.dividerLeadingInset)

                Button {
                    viewModel.showClearDataAlert = true
                } label: {
                    iconDestructiveRow(
                        title: String(localized: "settings.privacy.clear"),
                        systemImage: "trash.fill",
                        iconBackground: .red
                    )
                }
                .buttonStyle(.plain)

                if FeatureFlags.signInWithAppleEnabled, viewModel.isSignedIn {
                    settingsDivider()

                    Button {
                        viewModel.showDeleteAccountAlert = true
                    } label: {
                        destructiveRow(title: String(localized: "settings.privacy.delete_account"))
                    }
                    .buttonStyle(.plain)

                    settingsDivider()

                    Button {
                        viewModel.signOut()
                    } label: {
                        navigationRow(
                            title: String(localized: "settings.sign_out"),
                            trailing: ""
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .alert(String(localized: "settings.privacy.clear.confirm.title"), isPresented: $viewModel.showClearDataAlert) {
            Button(String(localized: "common.cancel"), role: .cancel) {}
            Button(String(localized: "common.delete"), role: .destructive) { viewModel.clearAllData() }
        }
        .alert(String(localized: "settings.privacy.delete.confirm.title"), isPresented: $viewModel.showDeleteAccountAlert) {
            Button(String(localized: "common.cancel"), role: .cancel) {}
            Button(String(localized: "common.delete"), role: .destructive) { viewModel.deleteAccount() }
        }
    }

    private var versionFooter: some View {
        Text(appVersionString)
            .font(.caption)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .padding(.bottom, AppSpacing.lg)
    }

    // MARK: - Appearance picker

    private var appearancePickerContent: some View {
        @Bindable var appSettings = appSettings

        return VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text(String(localized: "settings.appearance.subtitle"))
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(spacing: 2) {
                appearanceSegment(
                    mode: .off,
                    systemImage: "sun.max.fill",
                    iconColor: .yellow,
                    title: String(localized: "settings.appearance.light"),
                    selection: $appSettings.appearanceMode
                )
                appearanceSegment(
                    mode: .on,
                    systemImage: "moon.fill",
                    iconColor: .primary,
                    title: String(localized: "settings.appearance.dark"),
                    selection: $appSettings.appearanceMode
                )
                appearanceSegment(
                    mode: .system,
                    systemImage: "circle.lefthalf.filled",
                    iconColor: .primary,
                    title: String(localized: "settings.appearance.system"),
                    selection: $appSettings.appearanceMode
                )
            }
            .padding(2)
            .background(Color(.tertiarySystemFill), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
    }

    private func appearanceSegment(
        mode: AppearanceMode,
        systemImage: String,
        iconColor: Color,
        title: String,
        selection: Binding<AppearanceMode>
    ) -> some View {
        let isSelected = selection.wrappedValue == mode

        return Button {
            selection.wrappedValue = mode
        } label: {
            HStack(spacing: 6) {
                Image(systemName: systemImage)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(iconColor)

                Text(title)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .padding(.horizontal, 4)
            .background(
                isSelected ? Color(.secondarySystemGroupedBackground) : Color.clear,
                in: RoundedRectangle(cornerRadius: 6, style: .continuous)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Stress threshold

    private var stressAlertThresholdRow: some View {
        HStack(alignment: .top, spacing: AppSpacing.sm) {
            SettingsRowIcon(
                systemImage: "exclamationmark.triangle.fill",
                background: Color(.systemYellow)
            )

            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                        Text(String(localized: "settings.notifications.threshold"))
                            .font(.body)
                            .foregroundStyle(.primary)

                        Text(String(localized: "settings.notifications.threshold.footer"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: AppSpacing.sm)

                    Text("\(Int(stressThreshold))")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }

                Slider(value: $stressThreshold, in: 0...100, step: 1)

                HStack {
                    Text("0")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(String(localized: "stress.category.low"))
                        .font(.caption)
                        .foregroundStyle(AppColors.stressColor(for: .low))
                    Spacer()
                    Text(String(localized: "stress.category.moderate"))
                        .font(.caption)
                        .foregroundStyle(AppColors.stressColor(for: .moderate))
                    Spacer()
                    Text(String(localized: "stress.category.high"))
                        .font(.caption)
                        .foregroundStyle(AppColors.stressColor(for: .high))
                    Spacer()
                    Text("100")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, rowVerticalPadding)
        .onChange(of: stressThreshold) { _, newValue in
            let threshold = Int(newValue.rounded())
            AppSettings.stressAlertThreshold = threshold
            viewModel.profile?.notifThreshold = threshold
            viewModel.saveProfile()
            WatchConnectivityManager.shared.pushNotificationSettingsToWatch()
        }
        .onAppear {
            stressThreshold = Double(AppSettings.stressAlertThreshold)
        }
    }

    // MARK: - Mood reminder

    private var moodReminderTimeBinding: Binding<Date> {
        Binding(
            get: {
                let interval = moodReminderTimeInterval > 0
                    ? moodReminderTimeInterval
                    : AppSettings.moodReminderTime.timeIntervalSince1970
                return Date(timeIntervalSince1970: interval)
            },
            set: { moodReminderTimeInterval = $0.timeIntervalSince1970 }
        )
    }

    private var moodReminderToggleRow: some View {
        permissionToggleRow(
            title: String(localized: "settings.mood_reminder.title"),
            subtitle: String(localized: "settings.mood_reminder.subtitle"),
            systemImage: "calendar.badge.clock",
            iconBackground: Color(red: 0.2, green: 0.6, blue: 0.4),
            isOn: $moodReminderEnabled
        )
    }

    private var moodReminderTimeRow: some View {
        HStack {
            Text(String(localized: "settings.mood_reminder.time"))
                .font(AppTypography.rowPrimary)
                .foregroundStyle(AppColors.label)
            Spacer()
            DatePicker(
                "",
                selection: moodReminderTimeBinding,
                displayedComponents: .hourAndMinute
            )
            .labelsHidden()
        }
        .padding(.vertical, rowVerticalPadding)
        .transition(.opacity.combined(with: .move(edge: .top)))
    }

    private func syncMoodReminderSchedule(enabled: Bool) {
        if enabled {
            Task {
                _ = try? await NotificationManager.shared.requestAuthorization()
                NotificationManager.shared.scheduleDailyMoodReminder(at: moodReminderTimeBinding.wrappedValue)
            }
        } else {
            NotificationManager.shared.cancelDailyMoodReminder()
        }
    }

    // MARK: - iCloud

    @ViewBuilder
    private var iCloudSyncContent: some View {
        if FeatureFlags.iCloudCapabilityAvailable {
            VStack(spacing: 0) {
                permissionToggleRow(
                    title: String(localized: "settings.privacy.icloud.toggle"),
                    subtitle: String(localized: "settings.privacy.icloud.footer"),
                    systemImage: "icloud.fill",
                    iconBackground: Color(red: 0.0, green: 0.5, blue: 1.0),
                    isOn: iCloudToggleBinding
                )

                if !iCloudSyncEnabled {
                    Text(String(localized: "settings.privacy.icloud.sync_stop_restart"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.leading, SettingsRowIconMetrics.dividerLeadingInset)
                        .padding(.bottom, rowVerticalPadding)
                    // PRIVACY FIX: Inform user sync stop requires restart
                }

                settingsDivider(leading: SettingsRowIconMetrics.dividerLeadingInset)

                iCloudSyncStatusRow

                if showICloudRestartBanner {
                    settingsDivider(leading: SettingsRowIconMetrics.dividerLeadingInset)
                    iCloudRestartBanner
                }
            }
        } else {
            permissionToggleRow(
                title: String(localized: "settings.privacy.icloud.toggle"),
                subtitle: String(localized: "settings.privacy.icloud.requires_sign_in"),
                systemImage: "icloud.fill",
                iconBackground: Color(red: 0.0, green: 0.5, blue: 1.0),
                isOn: .constant(false)
            )
            .disabled(true)
            .opacity(0.7)
        }
    }

    private var iCloudSyncStatusRow: some View {
        HStack(spacing: AppSpacing.sm) {
            Image(systemName: viewModel.iCloudSyncDisplay.iconName)
                .font(.body.weight(.semibold))
                .foregroundStyle(viewModel.iCloudSyncDisplay.iconColor)

            Text(viewModel.iCloudStatus)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
        .padding(.leading, SettingsRowIconMetrics.dividerLeadingInset)
        .padding(.vertical, rowVerticalPadding)
    }

    private var iCloudRestartBanner: some View {
        HStack(spacing: AppSpacing.sm) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(Color(uiColor: .systemOrange))
            Text(String(localized: "icloud.sync.restart_banner"))
                .font(AppTypography.metadata)
                .foregroundStyle(AppColors.label)
            Spacer(minLength: 0)
        }
        .padding(.vertical, rowVerticalPadding)
    }

    private var exportOptionsSheet: some View {
        NavigationStack {
            Form {
                Section(String(localized: "settings.privacy.export")) {
                    Picker(String(localized: "export.format"), selection: $exportType) {
                        Text(String(localized: "export.pdf")).tag(ExportType.pdf)
                        Text(String(localized: "export.csv")).tag(ExportType.csv)
                    }
                    DatePicker(
                        String(localized: "history.custom.start"),
                        selection: $exportStart,
                        displayedComponents: .date
                    )
                    DatePicker(
                        String(localized: "history.custom.end"),
                        selection: $exportEnd,
                        displayedComponents: .date
                    )
                }
            }
            .navigationTitle(String(localized: "settings.privacy.export_data"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "common.cancel")) {
                        showExportOptions = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "settings.privacy.export.action")) {
                        showExportOptions = false
                        viewModel.exportData(type: exportType, from: exportStart, to: exportEnd)
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    // MARK: - Layout primitives

    private func settingsSection<Content: View>(
        title: String,
        systemImage: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: headerCardSpacing) {
            SectionHeaderView(systemImage: systemImage, title: title)
            content()
                .frame(maxWidth: .infinity, alignment: .leading)
                .homeScreenCard(padding: cardPadding)
        }
    }

    private func settingsDivider(leading: CGFloat? = nil) -> some View {
        Group {
            if let leading {
                Divider()
                    .padding(.leading, leading)
            } else {
                Divider()
            }
        }
    }

    // MARK: - Rows

    private func permissionToggleRow(
        title: String,
        subtitle: String,
        systemImage: String,
        iconBackground: Color,
        isOn: Binding<Bool>
    ) -> some View {
        HStack(alignment: .center, spacing: AppSpacing.sm) {
            SettingsRowIcon(systemImage: systemImage, background: iconBackground)

            VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                Text(title)
                    .font(.body)
                    .foregroundStyle(.primary)

                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: AppSpacing.sm)

            Toggle("", isOn: isOn)
                .labelsHidden()
        }
        .padding(.vertical, rowVerticalPadding)
    }

    private func toggleRow(title: String, subtitle: String, isOn: Binding<Bool>) -> some View {
        HStack(alignment: .center, spacing: AppSpacing.sm) {
            VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                Text(title)
                    .font(.body)
                    .foregroundStyle(.primary)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: AppSpacing.sm)
            Toggle("", isOn: isOn)
                .labelsHidden()
        }
        .padding(.vertical, rowVerticalPadding)
    }

    private func navigationRow(title: String, trailing: String) -> some View {
        navigationRowContent(title: title, trailing: trailing)
            .frame(minHeight: AppSpacing.minTouchTarget)
            .padding(.vertical, rowVerticalPadding)
    }

    private func iconNavigationRow(
        title: String,
        trailing: String,
        systemImage: String,
        iconBackground: Color
    ) -> some View {
        HStack(alignment: .center, spacing: AppSpacing.sm) {
            SettingsRowIcon(systemImage: systemImage, background: iconBackground)

            navigationRowContent(title: title, trailing: trailing)
        }
        .frame(minHeight: AppSpacing.minTouchTarget)
        .padding(.vertical, rowVerticalPadding)
    }

    private func navigationRowContent(title: String, trailing: String) -> some View {
        HStack {
            Text(title)
                .font(.body)
                .foregroundStyle(.primary)
            Spacer()
            if !trailing.isEmpty {
                Text(trailing)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color(.tertiaryLabel))
        }
    }

    private func destructiveRow(title: String) -> some View {
        Text(title)
            .font(.body)
            .foregroundStyle(AppColors.destructive)
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(minHeight: AppSpacing.minTouchTarget)
            .padding(.vertical, rowVerticalPadding)
    }

    private func iconDestructiveRow(
        title: String,
        systemImage: String,
        iconBackground: Color
    ) -> some View {
        HStack(alignment: .center, spacing: AppSpacing.sm) {
            SettingsRowIcon(systemImage: systemImage, background: iconBackground)

            Text(title)
                .font(.body)
                .foregroundStyle(AppColors.destructive)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(minHeight: AppSpacing.minTouchTarget)
        .padding(.vertical, rowVerticalPadding)
    }

    // MARK: - Profile helpers

    private var profileAvatar: some View {
        Group {
            if let image = cachedAvatarImage {
                Image(uiImage: image)
                    .resizable()
                    .interpolation(.medium)
                    .scaledToFill()
            } else {
                ZStack {
                    Circle()
                        .fill(profileAvatarGradient)
                    Text(displayNameInitial)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                }
            }
        }
        .frame(width: avatarSize, height: avatarSize)
        .clipShape(Circle())
    }

    private var profileAvatarWithCameraBadge: some View {
        profileAvatar
            .overlay(alignment: .bottomTrailing) {
                PhotosPicker(selection: $photoItem, matching: .images) {
                    Image(systemName: "camera.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 26, height: 26)
                        .background(AppColors.appPrimary, in: Circle())
                }
                .buttonStyle(.plain)
                .offset(x: 4, y: 4)
                .accessibilityLabel(String(localized: "settings.profile.change_photo"))
            }
    }

    private var displayName: String {
        let name = viewModel.profile?.displayName ?? ""
        return name.isEmpty ? String(localized: "settings.profile.anonymous") : name
    }

    private var displayNameInitial: String {
        String(displayName.prefix(1)).uppercased()
    }

    private var emailDisplayValue: String {
        if let email = viewModel.profile?.email, !email.isEmpty {
            return email
        }
        return String(localized: "settings.profile.member")
    }

    private var quietHoursLabel: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return "\(formatter.string(from: AppSettings.quietHoursStart)) – \(formatter.string(from: AppSettings.quietHoursEnd))"
    }

    private var appVersionString: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "—"
        return "Stretheo v\(version) (\(build))"
    }

    private var healthBinding: Binding<Bool> {
        Binding(
            get: { AppSettings.healthSyncEnabled },
            set: { enabled in Task { await viewModel.toggleHealthSync(enabled) } }
        )
    }

    private var notificationsBinding: Binding<Bool> {
        Binding(
            get: { AppSettings.notificationsEnabled },
            set: { enabled in Task { await viewModel.toggleNotifications(enabled) } }
        )
    }

    private var iCloudToggleBinding: Binding<Bool> {
        Binding(
            get: { iCloudSyncEnabled },
            set: { newValue in
                handleICloudToggleChange(newValue)
            }
        )
    }

    private func handleICloudToggleChange(_ enabled: Bool) {
        if enabled {
            iCloudSyncEnabled = true
            Task {
                do {
                    try await viewModel.validateICloudAccountBeforeEnable()
                    showICloudRestartAlert = true
                    await viewModel.syncProfileICloudPreference(true)
                    updateICloudRestartBanner()
                } catch {
                    iCloudSyncEnabled = false
                    viewModel.errorMessage = (error as? AppError)?.errorDescription ?? error.localizedDescription
                    viewModel.showError = true
                    showICloudRestartBanner = false
                }
            }
        } else {
            iCloudSyncEnabled = false
            showICloudRestartBanner = false
            showICloudRestartAlert = false
            // PRIVACY FIX: stop debounced CloudKit exports immediately when the user disables sync
            CloudKitSaveDebouncer.shared.configure(cloudKitEnabled: false)
            Task {
                await viewModel.syncProfileICloudPreference(false)
                updateICloudRestartBanner()
            }
        }
    }

    private func updateICloudRestartBanner() {
        guard FeatureFlags.iCloudCapabilityAvailable else {
            showICloudRestartBanner = false
            return
        }
        showICloudRestartBanner = iCloudSyncEnabled != dependencies.iCloudSyncEnabledAtLaunch
        if showICloudRestartBanner {
            Task { await viewModel.refreshICloudSyncDisplay(userEnabled: iCloudSyncEnabled) }
        }
    }

    #if DEBUG
    private func runDebugBackgroundMeasurement() async {
        StretheoLog.settings.debug("Starting manual background simulation")

        do {
            let profile = try dependencies.profileRepository.fetchOrCreateProfile()

            let input = try await dependencies.healthKitManager.fetchHealthInput(
                birthMonth: profile.birthMonth,
                birthYear: profile.birthYear,
                sex: profile.sex
            )
            StretheoLog.settings.debug("Health snapshot assembled for manual simulation")

            let result = StressAlgorithmEngine().compute(from: input)
            let measurement = try await dependencies.stressRepository.save(
                result: result,
                input: input,
                trigger: .manual
            )
            StretheoLog.settings.debug("Result saved — id: \(measurement.id)")

            let threshold = AppSettings.stressAlertThreshold
            StretheoLog.settings.debug("Evaluating notification gates against threshold")

            if result.level >= threshold {
                StretheoLog.settings.debug("At or above threshold — evaluating notification gates")
                await dependencies.notificationManager.scheduleStressAlertIfNeeded(
                    level: result.level,
                    category: result.category,
                    stressRepository: dependencies.stressRepository
                )
            } else {
                StretheoLog.settings.debug("Below threshold — no notification")
            }

            StretheoLog.settings.debug("Background simulation complete")
        } catch AppError.noHealthData {
            StretheoLog.settings.error("Failed — no health signal available")
        } catch {
            StretheoLog.settings.error("Failed — \(error.localizedDescription)")
        }
    }
    #endif
}

// MARK: - Quiet hours

struct QuietHoursSettingsView: View {
    @Environment(AppSettingsStore.self) private var appSettings
    @Bindable var viewModel: SettingsViewModel

    var body: some View {
        @Bindable var appSettings = appSettings

        Form {
            QuietHoursPicker(start: $appSettings.quietHoursStart, end: $appSettings.quietHoursEnd)
        }
        .onChange(of: appSettings.quietHoursStart) { _, _ in
            viewModel.syncQuietHoursToProfile()
        }
        .onChange(of: appSettings.quietHoursEnd) { _, _ in
            viewModel.syncQuietHoursToProfile()
        }
        .navigationTitle(String(localized: "settings.quiet.title"))
    }
}
