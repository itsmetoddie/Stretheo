//
//  FeatureFlags.swift
//  Stretheo
//
//  Toggle paid-program capabilities (iCloud, Sign in with Apple).
//  Requires matching entitlements in Stretheo.entitlements.
//

import Foundation

enum FeatureFlags {
    /// Entitlement / build capability — not the user's Settings toggle.
    static let iCloudCapabilityAvailable = true

    /// User preference from UserDefaults + capability (runtime CloudKit / sync).
    static var iCloudSyncEnabled: Bool {
        iCloudCapabilityAvailable && AppSettings.iCloudSyncEnabled
    }

    /// Sign in with Apple UI and AuthManager flows. Requires Sign in with Apple in entitlements.
    static let signInWithAppleEnabled = true
}
