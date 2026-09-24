//
//  StressDataActor.swift
//  Stretheo
//
//  Background SwiftData writes for stress measurements and mood entries.
//

import Foundation
import SwiftData

@ModelActor
actor StressDataActor {
    func saveStressMeasurement(
        id: UUID,
        stressLevel: Int,
        stressCategoryRaw: String,
        triggerTypeRaw: String,
        measuredAt: Date,
        createdAt: Date,
        profileID: UUID?,
        healthInput: HealthInput
    ) throws {
        let profile = try resolveProfile(profileID: profileID)
        let snapshot = HealthSnapshot(from: healthInput, recordedAt: measuredAt)
        let measurement = StressMeasurement(
            id: id,
            stressLevel: stressLevel,
            stressCategory: StressCategory(rawValue: stressCategoryRaw) ?? .low,
            triggerType: TriggerType(rawValue: triggerTypeRaw) ?? .automatic,
            measuredAt: measuredAt,
            createdAt: createdAt,
            userProfile: profile,
            healthSnapshot: snapshot
        )
        modelContext.insert(measurement)
        try commitSave()
    }

    func saveFromWatch(
        stressLevel: Int,
        stressCategoryRaw: String,
        measuredAt: Date,
        hrv: Double?,
        heartRate: Double?
    ) throws {
        if try hasMeasurementNear(measuredAt: measuredAt) {
            return
        }

        let profile = try fetchOrCreateProfile()
        let input = HealthInput(
            hrv: hrv,
            restingHeartRate: nil,
            currentHeartRate: heartRate,
            respiratoryRate: nil,
            wristTemperature: nil,
            activityType: nil,
            sleepDuration: nil,
            sleepQualityScore: nil,
            birthMonth: profile.birthMonth,
            birthYear: profile.birthYear,
            sex: profile.sex
        )

        let snapshot = HealthSnapshot(from: input, recordedAt: measuredAt)
        let measurement = StressMeasurement(
            stressLevel: stressLevel,
            stressCategory: StressCategory(rawValue: stressCategoryRaw) ?? StressCategory.from(level: stressLevel),
            triggerType: .automaticWatch,
            measuredAt: measuredAt,
            userProfile: profile,
            healthSnapshot: snapshot
        )
        modelContext.insert(measurement)
        try commitSave()
    }

    func deleteStressMeasurement(id: PersistentIdentifier) throws {
        guard let measurement = modelContext.model(for: id) as? StressMeasurement else { return }
        if let snapshot = measurement.healthSnapshot {
            modelContext.delete(snapshot)
        }
        modelContext.delete(measurement)
        try commitSave()
    }

    func saveMoodEntry(
        id: UUID,
        moodScore: Int,
        note: String,
        entryDate: Date,
        createdAt: Date,
        profileID: UUID?
    ) throws {
        let profile = try resolveProfile(profileID: profileID)
        let word = MoodEntry.normalizedMoodWord(note.isEmpty ? nil : note)
        let entry = MoodEntry(
            id: id,
            moodScore: moodScore,
            moodWord: word,
            entryDate: entryDate,
            createdAt: createdAt,
            userProfile: profile
        )
        modelContext.insert(entry)
        try commitSave()
    }

    func deleteMoodEntry(id: PersistentIdentifier) throws {
        guard let entry = modelContext.model(for: id) as? MoodEntry else { return }
        modelContext.delete(entry)
        try commitSave()
    }

    // MARK: - Private

    private func commitSave() throws {
        try modelContext.save()
    }

    private func hasMeasurementNear(measuredAt: Date) throws -> Bool {
        let start = measuredAt.addingTimeInterval(-0.5)
        let end = measuredAt.addingTimeInterval(0.5)
        var descriptor = FetchDescriptor<StressMeasurement>(
            predicate: #Predicate { $0.measuredAt >= start && $0.measuredAt <= end }
        )
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first != nil
    }

    private func resolveProfile(profileID: UUID?) throws -> UserProfile {
        if let profileID {
            var descriptor = FetchDescriptor<UserProfile>(
                predicate: #Predicate { $0.id == profileID }
            )
            descriptor.fetchLimit = 1
            if let profile = try modelContext.fetch(descriptor).first {
                return profile
            }
        }
        return try fetchOrCreateProfile()
    }

    private func fetchOrCreateProfile() throws -> UserProfile {
        var descriptor = FetchDescriptor<UserProfile>()
        descriptor.fetchLimit = 1
        if let existing = try modelContext.fetch(descriptor).first {
            return existing
        }
        let profile = UserProfile()
        modelContext.insert(profile)
        return profile
    }
}
