//
//  CheckInRange.swift
//  Stretheo
//

import Foundation

enum CheckInRange: String, CaseIterable, Identifiable {
    case today
    case week
    case month
    case all

    var id: String { rawValue }

    var title: String {
        switch self {
        case .today: String(localized: "checkins.range.today")
        case .week: String(localized: "checkins.range.week")
        case .month: String(localized: "checkins.range.month")
        case .all: String(localized: "checkins.range.all")
        }
    }
}
