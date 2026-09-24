//
//  StressDomainEnums.swift
//  StretheoShared
//

import Foundation

enum StressCategory: String, Codable, CaseIterable, Sendable {
    case low
    case moderate
    case high

    nonisolated static func from(level: Int) -> StressCategory {
        let clamped = min(max(level, 0), 100)
        switch clamped {
        case 0...33: return .low
        case 34...66: return .moderate
        default: return .high
        }
    }
}

enum ProfileSex: String, Codable, CaseIterable, Sendable {
    case male
    case female
    case other
}

enum TriggerType: String, Codable, CaseIterable, Sendable {
    case manual
    case automatic
    case automaticWatch
}
