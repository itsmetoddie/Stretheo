//
//  AnimatedCard.swift
//  Stretheo
//

import SwiftUI

struct AnimatedCardModifier: ViewModifier {
    let index: Int
    @State private var visible: Bool = false

    func body(content: Content) -> some View {
        content
            .opacity(visible ? 1.0 : 0.0)
            .offset(y: visible ? 0 : 16)
            .animation(
                .spring(response: 0.4, dampingFraction: 0.82)
                    .delay(Double(min(index, 5)) * 0.05),
                value: visible
            )
            .onDisappear {
                visible = false
            }
            .onAppear {
                visible = true
            }
    }
}

extension View {
    func animatedCard(index: Int = 0) -> some View {
        modifier(AnimatedCardModifier(index: index))
    }
}
