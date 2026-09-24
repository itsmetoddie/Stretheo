//
//  MoodScaleLegend.swift
//  Stretheo
//

import SwiftUI

struct MoodScaleLegend: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionHeaderView(
                systemImage: "chart.bar.fill",
                title: String(localized: "mood.scale.title")
            )

            ForEach(MoodScaleEntry.all, id: \.id) { entry in
                HStack(spacing: AppSpacing.sm) {
                    Text(entry.emoji)
                        .font(.body)
                    Text(entry.label)
                        .font(.subheadline)
                        .foregroundStyle(.primary)
                    Spacer()
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(AppColors.moodColor(for: entry.id))
                        .frame(width: 44, height: 6)
                }
                .padding(.horizontal, AppSpacing.md)
                .padding(.vertical, 7)
            }
            .padding(.bottom, AppSpacing.xs)
        }
        .homeScreenCard(padding: 0)
    }
}
