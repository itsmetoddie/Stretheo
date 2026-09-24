//
//  SwiftDataSchema.swift
//  Stretheo
//
//  Central schema definitions for dual ModelContainer setup.
//

import SwiftData

enum SwiftDataSchema {
    /// User-owned data — optional CloudKit private sync when enabled at launch.
    static let userModels: [any PersistentModel.Type] = [
        StressMeasurement.self,
        HealthSnapshot.self,
        MoodEntry.self,
        NotificationLog.self,
        ExportLog.self,
        UserProfile.self
    ]

    /// Cached articles from CloudKit public database — local only.
    static let articleModels: [any PersistentModel.Type] = [
        Article.self
    ]

    static var userSchema: Schema {
        Schema(userModels)
    }

    static var articleSchema: Schema {
        Schema(articleModels)
    }

    // MARK: - Migration notes
    //
    // ModelContainerFactory uses SwiftData automatic lightweight migration (no custom plan).
    // Prefer additive model changes (optional properties with defaults).
    // If a custom SchemaMigrationPlan is required later, each VersionedSchema must differ
    // in model layout — duplicate checksums occur when multiple versions list the same types.
    // - User and Article containers version independently.
    // - Enum storage uses raw String fields on models for stability.
}
