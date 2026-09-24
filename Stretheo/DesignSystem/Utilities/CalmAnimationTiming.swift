//
//  CalmAnimationTiming.swift
//  Stretheo
//

import UIKit

enum CalmAnimationTiming {
    static var reduceMotion: Bool {
        UIAccessibility.isReduceMotionEnabled
    }

    static func duration(_ normal: TimeInterval) -> TimeInterval {
        reduceMotion ? 0 : normal
    }
}
