//
//  TabScrollSubtitle.swift
//  Stretheo
//
//  Tab explanatory subtitle — first scroll item, scrolls away with content.
//

import SwiftUI

struct TabScrollSubtitle: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 4)
            .padding(.bottom, 8)
    }
}
