//
//  PrivacyFileAttributes.swift
//  Stretheo
//

import Foundation

enum PrivacyFileAttributes {
    /// PRIVACY FIX: encrypt at rest when locked and exclude from iCloud device backup.
    static func applySensitiveFileProtection(at url: URL) {
        try? FileManager.default.setAttributes(
            [.protectionKey: FileProtectionType.completeUnlessOpen],
            ofItemAtPath: url.path
        )
        var resourceValues = URLResourceValues()
        resourceValues.isExcludedFromBackup = true
        var mutableURL = url
        try? mutableURL.setResourceValues(resourceValues)
    }
}
