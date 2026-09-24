//
//  UserProfileRepository.swift
//  Stretheo
//

import Foundation
import SwiftData

// MARK: - Protocol

@MainActor
protocol UserProfileRepositoryProtocol: AnyObject {
    func fetchOrCreateProfile() throws -> UserProfile
    func fetchProfile() throws -> UserProfile?
    func save() throws
    func deleteAll() throws
}

// MARK: - SwiftData Implementation

@MainActor
final class SwiftDataUserProfileRepository: UserProfileRepositoryProtocol {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    func fetchOrCreateProfile() throws -> UserProfile {
        if let existing = try fetchProfile() {
            return existing
        }
        let profile = UserProfile()
        context.insert(profile)
        try RepositoryHelpers.save(context, contextLabel: "UserProfile.create")
        return profile
    }

    func fetchProfile() throws -> UserProfile? {
        var descriptor = FetchDescriptor<UserProfile>()
        descriptor.fetchLimit = 1
        do {
            return try context.fetch(descriptor).first
        } catch {
            throw AppError.persistence(error, context: "UserProfile.fetch")
        }
    }

    func save() throws {
        try RepositoryHelpers.save(context, contextLabel: "UserProfile.save")
    }

    func deleteAll() throws {
        do {
            try context.delete(model: UserProfile.self)
            try RepositoryHelpers.save(context, contextLabel: "UserProfile.deleteAll")
        } catch {
            throw AppError.persistence(error, context: "UserProfile.deleteAll")
        }
    }
}
