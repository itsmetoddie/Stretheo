//
//  HistoryMeasurementSnapshot.swift
//  Stretheo
//

import Foundation

/// Sendable stress row for History chart loading off the main actor.
struct HistoryMeasurementSnapshot: Sendable, Equatable {
    let id: UUID
    let measuredAt: Date
    let stressLevel: Int
}
