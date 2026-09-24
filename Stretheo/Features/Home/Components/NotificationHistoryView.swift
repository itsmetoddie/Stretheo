//
//  NotificationHistoryView.swift
//  Stretheo
//

import SwiftData
import SwiftUI

struct NotificationHistoryView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var notificationLogs: [NotificationLog] = []
    @State private var fetchLimit = Self.pageSize
    @State private var hasMore = false

    private static let pageSize = 50

    private var unreadNotifications: [NotificationLog] {
        notificationLogs.filter { !$0.isRead }
    }

    private var readNotifications: [NotificationLog] {
        notificationLogs.filter(\.isRead)
    }

    private var showsGroupedSections: Bool {
        !unreadNotifications.isEmpty && !readNotifications.isEmpty
    }

    var body: some View {
        NavigationStack {
            notificationList
                .background(.ultraThinMaterial)
                .navigationTitle(String(localized: "notification.history.title"))
                .navigationBarTitleDisplayMode(.inline)
                .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
                .toolbar {
                    if notificationLogs.contains(where: { !$0.isRead }) {
                        ToolbarItem(placement: .navigationBarLeading) {
                            Button(String(localized: "notification.history.mark_all_read")) {
                                markAllNotificationsRead()
                            }
                            .font(.subheadline)
                        }
                    }
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(String(localized: "Done")) {
                            dismiss()
                        }
                    }
                }
                .onAppear {
                    reloadNotifications()
                    markAllNotificationsRead()
                }
        }
        .background(.ultraThinMaterial)
    }

    @ViewBuilder
    private var notificationList: some View {
        if notificationLogs.isEmpty {
            NotificationEmptyState()
                .background(.ultraThinMaterial)
        } else {
            ScrollView {
                LazyVStack(spacing: 0) {
                    if showsGroupedSections {
                        sectionHeader(String(localized: "notification.history.section.new"))
                            .padding(.top, AppSpacing.sm)

                        ForEach(Array(unreadNotifications.enumerated()), id: \.element.id) { index, notification in
                            notificationRow(notification, staggerIndex: index)
                        }

                        sectionHeader(String(localized: "notification.history.section.earlier"))
                            .padding(.top, AppSpacing.md)

                        ForEach(Array(readNotifications.enumerated()), id: \.element.id) { index, notification in
                            notificationRow(
                                notification,
                                staggerIndex: unreadNotifications.count + index
                            )
                        }
                    } else {
                        ForEach(Array(notificationLogs.enumerated()), id: \.element.id) { index, notification in
                            notificationRow(notification, staggerIndex: index)
                        }
                    }

                    if hasMore {
                        loadMoreButton
                            .padding(.top, AppSpacing.md)
                            .padding(.horizontal, AppSpacing.md)
                    }
                }
                .padding(.top, AppSpacing.xs)
                .padding(.bottom, AppSpacing.md)
            }
        }
    }

    private var loadMoreButton: some View {
        Button {
            loadMoreNotifications()
        } label: {
            Text(String(localized: "common.load_more"))
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, AppSpacing.sm)
        }
        .buttonStyle(.plain)
        .foregroundStyle(Color.accentColor)
        .accessibilityLabel(String(localized: "common.load_more"))
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.caption)
            .fontWeight(.semibold)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, AppSpacing.md)
            .padding(.bottom, AppSpacing.xxs)
    }

    @ViewBuilder
    private func notificationRow(_ notification: NotificationLog, staggerIndex: Int) -> some View {
        NotificationHistoryRow(notification: notification, entranceDelayMs: staggerIndex * 60)
            .contextMenu {
                Button(role: .destructive) {
                    HapticFeedback.impact(.medium)
                    modelContext.delete(notification)
                    try? modelContext.save()
                    reloadNotifications()
                } label: {
                    Label(String(localized: "common.delete"), systemImage: "trash")
                }

                if !notification.isRead {
                    Button {
                        notification.isRead = true
                        try? modelContext.save()
                        reloadNotifications()
                    } label: {
                        Label(
                            String(localized: "notification.history.mark_read"),
                            systemImage: "checkmark.circle"
                        )
                    }
                }
            }
    }

    private func reloadNotifications() {
        var descriptor = FetchDescriptor<NotificationLog>(
            sortBy: [SortDescriptor(\.sentAt, order: .reverse)]
        )
        // Fetch one extra to detect whether another page exists without skipping/duplicating.
        descriptor.fetchLimit = fetchLimit + 1
        do {
            let fetched = try modelContext.fetch(descriptor)
            hasMore = fetched.count > fetchLimit
            notificationLogs = Array(fetched.prefix(fetchLimit))
        } catch {
            notificationLogs = []
            hasMore = false
        }
    }

    private func loadMoreNotifications() {
        fetchLimit += Self.pageSize
        reloadNotifications()
    }

    /// Marks every unread log in the store (not only the current page) so badge/history stay consistent.
    private func markAllNotificationsRead() {
        let descriptor = FetchDescriptor<NotificationLog>(
            predicate: #Predicate { !$0.isRead }
        )
        guard let unread = try? modelContext.fetch(descriptor), !unread.isEmpty else { return }
        for log in unread {
            log.isRead = true
        }
        try? modelContext.save()
        reloadNotifications()
    }
}

// MARK: - Empty state

private struct NotificationEmptyState: View {
    var body: some View {
        CardInlineEmptyState(
            systemImage: "bell.slash",
            title: String(localized: "notification.history.empty.title"),
            hint: String(localized: "notification.history.empty.message")
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Row

private struct NotificationHistoryRow: View {
    let notification: NotificationLog
    var entranceDelayMs: Int = 0

    @State private var appeared = false

    private var stressColor: Color {
        AppColors.stressDisplayColor(for: notification.stressLevelAtTrigger)
    }

    var body: some View {
        HStack(alignment: .top, spacing: AppSpacing.sm) {
            ZStack {
                Circle()
                    .fill(stressColor.opacity(0.2))
                    .frame(width: 46, height: 46)
                Text("\(notification.stressLevelAtTrigger)")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(stressColor)
            }
            .shadow(color: stressColor.opacity(0.3), radius: 6, x: 0, y: 2)

            VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                Text(notification.messageText)
                    .font(.subheadline)
                    .fontWeight(notification.isRead ? .regular : .semibold)
                    .foregroundStyle(.primary)

                Text(notification.sentAt.formatted(.relative(presentation: .named)))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)

            if !notification.isRead {
                Circle()
                    .fill(Color.accentColor)
                    .frame(width: 8, height: 8)
                    .shadow(color: Color.accentColor.opacity(0.8), radius: 4, x: 0, y: 0)
                    .padding(.top, AppSpacing.xxs)
            }
        }
        .padding(14)
        .background {
            LiquidGlassAccentCardBackground(
                accentColor: stressColor,
                isMuted: notification.isRead
            )
        }
        .stretheoShadow(LiquidGlassMetrics.cardShadow)
        .opacity(notification.isRead ? 0.75 : 1.0)
        .opacity(appeared ? 1.0 : 0.0)
        .offset(y: appeared ? 0 : 20)
        .padding(.horizontal, AppSpacing.md)
        .padding(.vertical, AppSpacing.xxs)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(notificationAccessibilityLabel)
        .task(id: entranceDelayMs) {
            guard entranceDelayMs > 0 else {
                animateEntrance()
                return
            }
            try? await Task.sleep(for: .milliseconds(entranceDelayMs))
            guard !Task.isCancelled else { return }
            animateEntrance()
        }
        .onAppear {
            if entranceDelayMs == 0 {
                animateEntrance()
            }
        }
    }

    private func animateEntrance() {
        guard !appeared else { return }
        withAnimation(.spring(response: 0.4, dampingFraction: 0.82)) {
            appeared = true
        }
    }

    private var notificationAccessibilityLabel: String {
        let when = notification.sentAt.formatted(.relative(presentation: .named))
        if notification.isRead {
            return String(
                format: String(localized: "accessibility.notification.row.read"),
                notification.stressLevelAtTrigger,
                notification.messageText,
                when
            )
        }
        return String(
            format: String(localized: "accessibility.notification.row.unread"),
            notification.stressLevelAtTrigger,
            notification.messageText,
            when
        )
    }
}
