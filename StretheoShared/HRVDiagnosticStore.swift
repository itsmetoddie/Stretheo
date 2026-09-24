//
//  HRVDiagnosticStore.swift
//  StretheoShared
//
//  Persists last HRV observer fire timestamps for TestFlight cadence diagnostics.
//  Not health data — diagnostic timestamps only.
//

import Foundation

public enum HRVDiagnosticStore: Sendable {
    private nonisolated static let watchLastObserverFireKey = "com.zapreff.Stretheo.hrvDiagnostic.watchLastObserverFire"
    private nonisolated static let iPhoneLastObserverFireKey = "com.zapreff.Stretheo.hrvDiagnostic.iPhoneLastObserverFire"

    public static let quietPeriodThreshold: TimeInterval = 4 * 60 * 60

    public nonisolated static func recordWatchObserverFire(at date: Date = .now) {
        UserDefaults.standard.set(date.timeIntervalSince1970, forKey: watchLastObserverFireKey)
    }

    public nonisolated static func watchLastObserverFire() -> Date? {
        timestampDate(forKey: watchLastObserverFireKey)
    }

    public nonisolated static func recordIPhoneObserverFire(at date: Date = .now) {
        UserDefaults.standard.set(date.timeIntervalSince1970, forKey: iPhoneLastObserverFireKey)
    }

    public nonisolated static func iPhoneLastObserverFire() -> Date? {
        timestampDate(forKey: iPhoneLastObserverFireKey)
    }

    private nonisolated static func timestampDate(forKey key: String) -> Date? {
        let timestamp = UserDefaults.standard.double(forKey: key)
        guard timestamp > 0 else { return nil }
        return Date(timeIntervalSince1970: timestamp)
    }
}
