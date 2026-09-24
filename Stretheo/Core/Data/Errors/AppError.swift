//
//  AppError.swift
//  Stretheo
//

import Foundation

/// Application-wide errors surfaced to use cases, repositories, and services.
enum AppError: LocalizedError, Sendable, Equatable {
    // MARK: - HealthKit

    case healthKitUnavailable
    case healthKitNotAuthorized
    case healthKitReadFailed(String)
    case noHealthData

    // MARK: - Persistence / SwiftData

    case persistenceFailed(String)
    case recordNotFound(String)
    case invalidData(String)

    // MARK: - CloudKit

    case cloudKitUnavailable
    case cloudKitFetchFailed(String)

    // MARK: - Export

    case exportFailed(String)

    // MARK: - Authentication

    case authenticationFailed(String)

    // MARK: - Profile

    case profileNotFound

    var errorDescription: String? {
        switch self {
        case .healthKitUnavailable:
            String(localized: "error.healthkit.unavailable")
        case .healthKitNotAuthorized:
            String(localized: "error.healthkit.unauthorized")
        case .healthKitReadFailed(let detail):
            String(localized: "error.healthkit.read \(detail)")
        case .noHealthData:
            String(localized: "error.healthkit.no_data")
        case .persistenceFailed(let detail):
            String(localized: "error.persistence \(detail)")
        case .recordNotFound(let detail):
            String(localized: "error.record_not_found \(detail)")
        case .invalidData(let detail):
            String(localized: "error.invalid_data \(detail)")
        case .cloudKitUnavailable:
            String(localized: "error.cloudkit.unavailable")
        case .cloudKitFetchFailed(let detail):
            String(localized: "error.cloudkit.fetch \(detail)")
        case .exportFailed(let detail):
            String(localized: "error.export \(detail)")
        case .authenticationFailed(let detail):
            String(localized: "error.auth \(detail)")
        case .profileNotFound:
            String(localized: "error.profile.not_found")
        }
    }

    /// Maps underlying storage errors into a stable `AppError`.
    static func persistence(_ error: Error, context: String) -> AppError {
        .persistenceFailed("\(context): \(error.localizedDescription)")
    }
}
