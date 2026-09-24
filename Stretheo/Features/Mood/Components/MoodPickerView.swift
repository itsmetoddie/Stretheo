//
//  MoodPickerView.swift
//  Stretheo
//

import SwiftUI

struct MoodPickerView: View {
    let selectedScore: Int?
    let onSelect: (Int) -> Void
    var reduceMotion: Bool = false

    @State private var bounceScore: Int?

    private let tileCornerRadius: CGFloat = 12

    var body: some View {
        HStack(spacing: AppSpacing.xs) {
            ForEach(MoodScaleEntry.all, id: \.id) { entry in
                moodTile(for: entry)
            }
        }
        .padding(.vertical, 2)
        .dynamicTypeSize(.large ... .accessibility3)
        .sensoryFeedback(.selection, trigger: selectedScore)
    }

    @ViewBuilder
    private func moodTile(for entry: MoodScaleEntry) -> some View {
        let isSelected = selectedScore == entry.id
        Button {
            let willDeselect = selectedScore == entry.id
            if reduceMotion {
                onSelect(entry.id)
                return
            }
            if willDeselect {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
                    onSelect(entry.id)
                }
            } else {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
                    bounceScore = entry.id
                    onSelect(entry.id)
                }
                withAnimation(.spring(response: 0.3, dampingFraction: 0.6).delay(0.15)) {
                    bounceScore = nil
                }
            }
        } label: {
            VStack(spacing: AppSpacing.xxs) {
                Text(entry.emoji)
                    .font(.title)
                Text("\(entry.id)")
                    .font(AppTypography.captionBold)
                    .foregroundStyle(isSelected ? Color.white : MoodColors.moodTextColor(for: entry.id))
            }
            .padding(3)
            .frame(maxWidth: .infinity, minHeight: AppSpacing.minTouchTarget)
            .scaleEffect(emojiScale(for: entry))
            .background(
                Self.moodTileBackground(for: entry.id, selected: isSelected),
                in: RoundedRectangle(cornerRadius: tileCornerRadius, style: .continuous)
            )
            .overlay {
                if isSelected {
                    RoundedRectangle(cornerRadius: tileCornerRadius, style: .continuous)
                        .stroke(MoodColors.moodColor(for: entry.id), lineWidth: 2)
                }
            }
            .padding(2)
        }
        .buttonStyle(.plain)
        .animation(
            reduceMotion ? nil : .spring(response: 0.35, dampingFraction: 0.6),
            value: selectedScore
        )
        .animation(
            reduceMotion ? nil : .spring(response: 0.35, dampingFraction: 0.6),
            value: bounceScore
        )
        .accessibilityLabel(entry.label)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func emojiScale(for entry: MoodScaleEntry) -> CGFloat {
        if reduceMotion { return 1.0 }
        if bounceScore == entry.id { return 1.25 }
        guard let selectedScore else { return 1.0 }
        if selectedScore == entry.id { return 1.15 }
        return 0.92
    }

    private static func moodTileBackground(for score: Int, selected: Bool) -> Color {
        MoodColors.moodColor(for: score).opacity(selected ? 0.5 : 0.35)
    }
}
