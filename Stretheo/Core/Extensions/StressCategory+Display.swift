//
//  StressCategory+Display.swift
//  Stretheo
//

import Foundation

extension StressCategory {
    var localizedTitle: String {
        switch self {
        case .low: String(localized: "stress.category.low")
        case .moderate: String(localized: "stress.category.moderate")
        case .high: String(localized: "stress.category.high")
        }
    }
}
