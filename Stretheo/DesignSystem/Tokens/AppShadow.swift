//
//  AppShadow.swift
//  Stretheo
//

import SwiftUI

enum AppShadow {
    static let card = ShadowStyle(color: Color.black.opacity(0.06), radius: 6, y: 2)
}

struct ShadowStyle {
    let color: Color
    let radius: CGFloat
    let y: CGFloat
}

extension View {
    func stretheoShadow(_ style: ShadowStyle) -> some View {
        shadow(color: style.color, radius: style.radius, x: 0, y: style.y)
    }
}
