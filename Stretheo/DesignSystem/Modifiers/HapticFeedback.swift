//
//  HapticFeedback.swift
//  Stretheo
//

import UIKit

/// Alias matching common naming; use `HapticFeedback` at call sites.
typealias Haptics = HapticFeedback

/// Reuses one `UIImpactFeedbackGenerator` and warms it with `prepare()` to avoid
/// repeated Core Haptics engine cold-starts.
final class PreparedImpactFeedbackGenerator {
    private let generator: UIImpactFeedbackGenerator

    init(style: UIImpactFeedbackGenerator.FeedbackStyle) {
        generator = UIImpactFeedbackGenerator(style: style)
    }

    func prepare() {
        generator.prepare()
    }

    func impact() {
        generator.impactOccurred()
    }

    func impactAndPrepare() {
        generator.impactOccurred()
        generator.prepare()
    }
}

enum HapticFeedback {
    private static let mediumImpact = UIImpactFeedbackGenerator(style: .medium)
    private static let lightImpact = UIImpactFeedbackGenerator(style: .light)
    private static let softImpact = UIImpactFeedbackGenerator(style: .soft)
    private static let notification = UINotificationFeedbackGenerator()

    static func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .medium) {
        switch style {
        case .light:
            lightImpact.impactOccurred()
            lightImpact.prepare()
        case .soft:
            softImpact.impactOccurred()
            softImpact.prepare()
        case .medium, .heavy, .rigid:
            mediumImpact.impactOccurred()
            mediumImpact.prepare()
        @unknown default:
            mediumImpact.impactOccurred()
            mediumImpact.prepare()
        }
    }

    static func light() {
        lightImpact.impactOccurred()
        lightImpact.prepare()
    }

    static func soft() {
        softImpact.impactOccurred()
        softImpact.prepare()
    }

    static func notification(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        notification.notificationOccurred(type)
        notification.prepare()
    }

    static func success() {
        notification(.success)
    }

    static func warning() {
        notification(.warning)
    }
}
