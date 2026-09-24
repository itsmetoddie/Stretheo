//
//  View+Extensions.swift
//  Stretheo
//

import SwiftUI

extension View {
    func stretheoScreen() -> some View {
        background(AppColors.appBackground.ignoresSafeArea())
    }

    /// Native large navigation title (Liquid Glass on iOS 26). Pair with `TabScrollSubtitle` as the first scroll item.
    func stretheoTabNavigation(title: String) -> some View {
        navigationTitle(title)
            .navigationBarTitleDisplayMode(.large)
            .stretheoNavigationBarStyle()
    }

    func errorBanner(
        _ message: String?,
        isPresented: Binding<Bool>,
        onDismiss: (() -> Void)? = nil
    ) -> some View {
        overlay(alignment: .top) {
            if isPresented.wrappedValue, let message {
                ErrorBannerView(message: message, isPresented: isPresented, onDismiss: onDismiss)
                    .padding(.top, AppSpacing.sm)
            }
        }
    }
}
