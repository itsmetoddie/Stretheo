//
//  MoodCalendarView.swift
//  Stretheo
//

import SwiftUI

struct MoodCalendarView: View {
    @Binding var displayedMonth: Date
    let moodByDay: [Date: Int]
    let moodFillByDay: [Date: Color]
    var onMonthChange: ((Date) -> Void)?

    @State private var selectedDay: DaySelection?

    private let columns = Array(repeating: GridItem(.flexible(), spacing: AppSpacing.xxs), count: 7)
    private let weekdaySymbols = Calendar.current.shortWeekdaySymbols
    private let calendar = Calendar.current

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            SectionHeaderView(
                systemImage: "calendar",
                title: String(localized: "history.mood_calendar.title")
            )

            HStack(spacing: AppSpacing.xs) {
                monthNavigationButton(
                    systemImage: "chevron.left",
                    accessibilityLabel: String(localized: "accessibility.calendar.previous_month")
                ) {
                    shiftMonth(by: -1)
                }

                Text(monthTitle)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity)

                monthNavigationButton(
                    systemImage: "chevron.right",
                    accessibilityLabel: String(localized: "accessibility.calendar.next_month")
                ) {
                    shiftMonth(by: 1)
                }
            }
            .padding(.horizontal, AppSpacing.md)

            LazyVGrid(columns: columns, spacing: AppSpacing.xxs) {
                ForEach(weekdaySymbols, id: \.self) { symbol in
                    Text(symbol)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                ForEach(daysInMonth, id: \.timeIntervalSince1970) { day in
                    dayCell(for: day)
                }
            }
            .padding(.horizontal, AppSpacing.md)

            moodLegend
                .padding(.horizontal, AppSpacing.md)
                .padding(.bottom, AppSpacing.md)
        }
        .homeScreenCard(padding: 0)
        .sheet(item: $selectedDay) { selection in
            dayDetail(for: selection.date)
                .presentationDetents([.medium])
        }
    }

    private var monthTitle: String {
        displayedMonth.formatted(.dateTime.month(.wide).year())
    }

    private var daysInMonth: [Date] {
        guard let interval = calendar.dateInterval(of: .month, for: displayedMonth) else { return [] }
        let startWeekday = calendar.component(.weekday, from: interval.start)
        let leading = (startWeekday - calendar.firstWeekday + 7) % 7
        var days: [Date] = []
        if leading > 0 {
            for offset in stride(from: leading, to: 0, by: -1) {
                if let day = calendar.date(byAdding: .day, value: -offset, to: interval.start) {
                    days.append(day)
                }
            }
        }
        var current = interval.start
        while current < interval.end {
            days.append(current)
            current = calendar.date(byAdding: .day, value: 1, to: current) ?? current
        }
        return days
    }

    @ViewBuilder
    private func dayCell(for day: Date) -> some View {
        let dayKey = calendar.startOfDay(for: day)
        let isCurrentMonth = calendar.isDate(day, equalTo: displayedMonth, toGranularity: .month)
        let isToday = calendar.isDateInToday(day)
        let score = moodByDay[dayKey]
        let fill = moodFillByDay[dayKey] ?? Color(.systemGray5)
        let dayNumber = calendar.component(.day, from: day)

        Button {
            if score != nil { selectedDay = DaySelection(date: dayKey) }
        } label: {
            ZStack {
                if isToday {
                    Circle()
                        .fill(Color(.systemBlue))
                        .frame(width: 36, height: 36)
                } else {
                    Circle()
                        .fill(fill)
                        .frame(width: 36, height: 36)
                }

                Text("\(dayNumber)")
                    .font(score != nil ? AppTypography.captionBold : AppTypography.caption)
                    .foregroundStyle(isToday ? Color.white : dayNumberColor(isCurrentMonth: isCurrentMonth))
            }
            .frame(height: 40)
        }
        .buttonStyle(.plain)
        .disabled(score == nil)
    }

    private func dayNumberColor(isCurrentMonth: Bool) -> Color {
        isCurrentMonth ? AppColors.label : AppColors.secondaryLabel.opacity(0.4)
    }

    private var moodLegend: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: AppSpacing.sm) {
                ForEach(MoodScaleEntry.all) { entry in
                    HStack(spacing: AppSpacing.xxs) {
                        Circle()
                            .fill(AppColors.moodColor(for: entry.id))
                            .frame(width: 10, height: 10)
                        Text(entry.label)
                            .font(.caption)
                            .foregroundStyle(AppColors.secondaryLabel)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func dayDetail(for day: Date) -> some View {
        let dayKey = calendar.startOfDay(for: day)
        let score = moodByDay[dayKey]
        VStack(spacing: AppSpacing.md) {
            if let score {
                Text(MoodScaleEntry.all.first(where: { $0.id == score })?.emoji ?? "😐")
                    .font(AppTypography.largeTitle)
                Text(MoodScaleEntry.all.first(where: { $0.id == score })?.label ?? "")
                    .font(AppTypography.sectionTitle)
                    .foregroundStyle(AppColors.label)
            } else {
                Text(String(localized: "history.calendar.no_entry"))
                    .foregroundStyle(AppColors.secondaryLabel)
            }
        }
        .padding()
    }

    private func monthNavigationButton(
        systemImage: String,
        accessibilityLabel: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.body.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
    }

    private func shiftMonth(by value: Int) {
        let newMonth = calendar.date(byAdding: .month, value: value, to: displayedMonth) ?? displayedMonth
        displayedMonth = newMonth
        onMonthChange?(newMonth)
    }
}

private struct DaySelection: Identifiable {
    let id: TimeInterval
    let date: Date

    init(date: Date) {
        self.date = date
        self.id = date.timeIntervalSince1970
    }
}
