//
//  RepositoryHelpers.swift
//  Stretheo
//

import OSLog
import SwiftData

enum RepositoryHelpers {
    @MainActor
    static func save(_ context: ModelContext, contextLabel: String) throws {
        try CloudKitSaveDebouncer.shared.scheduleSave(context, label: contextLabel)
    }

    @MainActor
    static func saveImmediately(_ context: ModelContext, contextLabel: String) throws {
        StretheoLog.rangeSwitch.debug("RANGE_SWITCH: ModelContext.save start label=\(contextLabel, privacy: .public)")
        let started = CFAbsoluteTimeGetCurrent()
        defer {
            let elapsedMs = (CFAbsoluteTimeGetCurrent() - started) * 1000
            StretheoLog.rangeSwitch.debug(
                "RANGE_SWITCH: ModelContext.save completed label=\(contextLabel, privacy: .public) elapsedMs=\(elapsedMs, privacy: .public)"
            )
        }
        do {
            try context.save()
        } catch {
            throw AppError.persistence(error, context: contextLabel)
        }
    }

    @MainActor
    static func fetchOrCreateUserProfile(in context: ModelContext) throws -> UserProfile {
        var descriptor = FetchDescriptor<UserProfile>()
        descriptor.fetchLimit = 1
        if let existing = try context.fetch(descriptor).first {
            return existing
        }
        let profile = UserProfile()
        context.insert(profile)
        return profile
    }
}
