//
//  SettingsRowIcon.swift
//  Stretheo
//

import SwiftUI

enum SettingsRowIconMetrics {
    static let size: CGFloat = 32
    static let cornerRadius: CGFloat = 7
    static let symbolPointSize: CGFloat = 16
    static let dividerLeadingInset: CGFloat = 52
}

struct SettingsRowIcon: View {
    let systemImage: String
    var symbolColor: Color = .white
    var background: Color

    var body: some View {
        Image(systemName: systemImage)
            .font(.system(size: SettingsRowIconMetrics.symbolPointSize, weight: .semibold))
            .foregroundStyle(symbolColor)
            .frame(width: SettingsRowIconMetrics.size, height: SettingsRowIconMetrics.size)
            .background(
                background,
                in: RoundedRectangle(cornerRadius: SettingsRowIconMetrics.cornerRadius, style: .continuous)
            )
    }
}
