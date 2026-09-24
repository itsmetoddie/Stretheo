//
//  StressResult.swift
//  StretheoShared
//

import Foundation

struct StressResult: Sendable, Equatable {
    let level: Int
    let category: StressCategory
    let breakdown: [String]
}
