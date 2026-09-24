//
//  BreathingExerciseCard.swift
//  Stretheo
//
//  Static preview + launcher — animation runs only in BreathingSessionView (fullScreenCover).
//

import SwiftUI

struct BreathingExerciseCard: View {
    @Binding var selectedTechniqueIndex: Int
    let onStart: () -> Void

    @State private var breathingDescriptionExpanded = false
    @ScaledMetric(relativeTo: .title) private var previewOrbSize: CGFloat = 100

    /// Index 0 = 4-7-8 Breathing (default).
    private var catalog: [BreathingTechnique] { BreathingTechnique.all }

    private var technique: BreathingTechnique {
        guard selectedTechniqueIndex >= 0, selectedTechniqueIndex < catalog.count else {
            return BreathingTechnique.fourSevenEight
        }
        return catalog[selectedTechniqueIndex]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionHeaderView(
                systemImage: "lungs.fill",
                title: String(localized: "home.breathing.title"),
                subtitle: String(localized: "home.breathing.subtitle")
            )

            VStack(alignment: .leading, spacing: AppSpacing.md) {
                techniquePicker

                staticPreview

                techniqueDetails

                PrimaryButton(
                    title: String(localized: "breathing.start"),
                    systemImage: "play.fill",
                    action: onStart
                )
            }
            .padding(.horizontal, AppSpacing.lg)
            .padding(.bottom, AppSpacing.lg)
        }
        .homeScreenCard(padding: 0)
        .animation(.easeInOut(duration: 0.25), value: selectedTechniqueIndex)
        .onChange(of: selectedTechniqueIndex) { _, _ in
            withAnimation(.easeInOut(duration: 0.2)) {
                breathingDescriptionExpanded = false
            }
        }
    }

    private var techniqueDetails: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            HStack(alignment: .firstTextBaseline) {
                Text(technique.name)
                    .font(AppTypography.sectionTitle)
                    .foregroundStyle(AppColors.label)
                Spacer(minLength: AppSpacing.sm)
                Text(technique.formattedDuration)
                    .font(AppTypography.metadata)
                    .foregroundStyle(AppColors.secondaryLabel)
            }

            Text(technique.subtitle)
                .font(AppTypography.label)
                .foregroundStyle(technique.accentColor)

            VStack(alignment: .leading, spacing: 6) {
                Text(technique.description)
                    .font(.subheadline)
                    .foregroundStyle(AppColors.secondaryLabel)
                    .lineLimit(breathingDescriptionExpanded ? nil : 3)
                    .animation(.easeInOut(duration: 0.25), value: breathingDescriptionExpanded)

                if breathingDescriptionExpanded {
                    Button {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            breathingDescriptionExpanded = false
                        }
                    } label: {
                        Text(String(localized: "breathing.show_less"))
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundStyle(Color.accentColor)
                    }
                    .buttonStyle(.plain)
                } else {
                    Button {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            breathingDescriptionExpanded = true
                        }
                    } label: {
                        Text(String(localized: "breathing.read_more"))
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundStyle(Color.accentColor)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var techniquePicker: some View {
        HStack(spacing: AppSpacing.xs) {
            techniquePill(index: 0, technique: BreathingTechnique.fourSevenEight)
            techniquePill(index: 1, technique: BreathingTechnique.boxBreathing)
            techniquePill(index: 2, technique: BreathingTechnique.coherent)
        }
        .frame(maxWidth: .infinity)
    }

    private func techniquePill(index: Int, technique: BreathingTechnique) -> some View {
        BreathingTechniquePill(
            technique: technique,
            isSelected: selectedTechniqueIndex == index
        ) {
            selectedTechniqueIndex = index
            HapticFeedback.light()
        }
    }

    /// Non-animated placeholder — the live session is BreathingSessionView only.
    private var staticPreview: some View {
        ZStack {
            Circle()
                .fill(AppColors.tertiarySystemFill)

            Circle()
                .strokeBorder(AppColors.segmentBorder, lineWidth: 2)

            BreathingTechniqueIcon(
                systemName: technique.systemImage,
                color: technique.accentColor,
                size: 24
            )
        }
        .frame(width: previewOrbSize, height: previewOrbSize)
        .frame(maxWidth: .infinity)
        .padding(.vertical, AppSpacing.sm)
        .accessibilityHidden(true)
    }
}

// MARK: - Technique icon

struct BreathingTechniqueIcon: View {
    let systemName: String
    let color: Color
    let size: CGFloat

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: size, weight: .semibold))
            .symbolRenderingMode(.monochrome)
            .foregroundStyle(color)
            .frame(width: size, height: size)
    }
}

// MARK: - Technique pill

private struct BreathingTechniquePill: View {
    let technique: BreathingTechnique
    let isSelected: Bool
    let onSelect: () -> Void

    private var pillLabel: String {
        if technique.id == BreathingTechnique.fourSevenEight.id {
            return "4-7-8"
        }
        if technique.id == BreathingTechnique.boxBreathing.id {
            return "Box"
        }
        return "Coherent"
    }

    var body: some View {
        Button(action: onSelect) {
            Text(pillLabel)
                .font(AppTypography.label)
                .foregroundStyle(isSelected ? technique.accentColor : .secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .padding(.horizontal, 8)
            .background(
                isSelected
                    ? technique.accentColor.opacity(0.12)
                    : Color(.tertiarySystemFill),
                in: RoundedRectangle(cornerRadius: AppRadius.pill, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.pill, style: .continuous)
                    .strokeBorder(
                        isSelected ? technique.accentColor : Color.clear,
                        lineWidth: 1.5
                    )
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(String(format: String(localized: "accessibility.breathing.technique"), technique.name))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
