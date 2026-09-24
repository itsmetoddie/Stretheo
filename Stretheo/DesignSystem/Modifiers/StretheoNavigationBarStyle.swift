//
//  StretheoNavigationBarStyle.swift
//  Stretheo
//
//  Large title: bold (not heavy). Subtitle: subheadline + secondary label color.
//  Toolbar uses static .ultraThinMaterial on iOS 26; iOS 27 introduces scroll-edge
//  glass intensity that responds to scroll position — not adopted while targeting iOS 26.
//

import SwiftUI
import UIKit

enum StretheoNavigationBarAppearance {
    static func applyTabScreenStyle() {
        let largeTitleFont = UIFont.systemFont(ofSize: 34, weight: .bold)
        let subtitleFont = UIFont.preferredFont(forTextStyle: .subheadline)

        func styledAppearance(from base: UINavigationBarAppearance) -> UINavigationBarAppearance {
            let appearance = base.copy()
            appearance.largeTitleTextAttributes = [
                .font: largeTitleFont,
                .foregroundColor: UIColor.label
            ]
            appearance.titleTextAttributes = [
                .font: UIFont.systemFont(ofSize: 17, weight: .semibold),
                .foregroundColor: UIColor.label
            ]
            if #available(iOS 26.0, *) {
                appearance.subtitleTextAttributes = [
                    .font: subtitleFont,
                    .foregroundColor: UIColor.secondaryLabel
                ]
            }
            return appearance
        }

        let standard = styledAppearance(from: UINavigationBarAppearance())
        let scrollEdge = styledAppearance(from: UINavigationBarAppearance())
        scrollEdge.configureWithTransparentBackground()

        let navBar = UINavigationBar.appearance()
        navBar.standardAppearance = standard
        navBar.scrollEdgeAppearance = scrollEdge
        navBar.compactAppearance = standard
    }
}

private struct StretheoNavigationBarStyleConfigurator: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> UIViewController {
        UIViewController()
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        StretheoNavigationBarAppearance.applyTabScreenStyle()
        uiViewController.navigationController?.navigationBar.setNeedsLayout()
    }
}

extension View {
    func stretheoNavigationBarStyle() -> some View {
        background(StretheoNavigationBarStyleConfigurator())
    }
}
