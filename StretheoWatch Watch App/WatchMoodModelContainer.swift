//
//  WatchMoodModelContainer.swift
//  StretheoWatch
//

import Foundation
import SwiftData

enum WatchMoodModelContainer {
    static let shared: ModelContainer = {
        let schema = SwiftDataSchema.userSchema
        let configuration = ModelConfiguration(
            "WatchUserData",
            schema: schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: .automatic
        )
        do {
            return try ModelContainer(for: schema, configurations: configuration)
        } catch {
            fatalError("Failed to create Watch mood ModelContainer: \(error.localizedDescription)")
        }
    }()
}
