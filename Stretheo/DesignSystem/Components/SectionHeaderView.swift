//
//  SectionHeaderView.swift
//  Stretheo
//

import SwiftUI

struct SectionHeaderView<Trailing: View>: View {
    let systemImage: String
    let title: String
    var subtitle: String?
    @ViewBuilder var trailing: () -> Trailing

    init(
        systemImage: String,
        title: String,
        subtitle: String? = nil,
        @ViewBuilder trailing: @escaping () -> Trailing
    ) {
        self.systemImage = systemImage
        self.title = title
        self.subtitle = subtitle
        self.trailing = trailing
    }

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: systemImage)
                .font(.body)
                .foregroundStyle(.secondary)

            if let subtitle, !subtitle.isEmpty {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.title3)
                        .fontWeight(.semibold)
                        .lineLimit(2)
                        .minimumScaleFactor(0.85)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .minimumScaleFactor(0.85)
                }
            } else {
                Text(title)
                    .font(.title3)
                    .fontWeight(.semibold)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
            }

            Spacer(minLength: 0)

            trailing()
        }
        .padding(.horizontal, AppSpacing.md)
        .padding(.top, AppSpacing.md)
        .padding(.bottom, AppSpacing.xs)
    }
}

extension SectionHeaderView where Trailing == EmptyView {
    init(systemImage: String, title: String, subtitle: String? = nil) {
        self.init(systemImage: systemImage, title: title, subtitle: subtitle) {
            EmptyView()
        }
    }
}
