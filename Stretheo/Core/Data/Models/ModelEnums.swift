//
//  ModelEnums.swift
//  Stretheo
//
//  Codable enums persisted via raw String/Int on @Model types.
//

import Foundation
import SwiftUI

enum ExportType: String, Codable, CaseIterable, Sendable {
    case pdf
    case csv
}

/// App appearance preference — stored in UserDefaults, not SwiftData.
enum AppearanceMode: String, Codable, CaseIterable, Sendable {
    /// Dark appearance.
    case on
    /// Light appearance.
    case off
    /// Follow the system setting.
    case system
}

extension AppearanceMode {
    /// `nil` means follow system — used with `.preferredColorScheme`.
    var preferredColorScheme: ColorScheme? {
        switch self {
        case .on: .dark
        case .off: .light
        case .system: nil
        }
    }
}

enum DataValidation {
    static let moodScoreRange = 1...5
    static let moodWordMaxLength = 60
    static let stressLevelRange = 0...100
    static let notificationThresholdRange = 0...100
}
