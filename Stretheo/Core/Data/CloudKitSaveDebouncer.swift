//
//  CloudKitSaveDebouncer.swift
//  Stretheo
//
//  Coalesces rapid SwiftData saves when CloudKit automatic sync is active.
//

import Foundation
import OSLog
import SwiftData

@MainActor
final class CloudKitSaveDebouncer {
    static let shared = CloudKitSaveDebouncer()

    private let debounceInterval: Duration = .seconds(5)
    private var pendingTask: Task<Void, Never>?
    private var isCloudKitEnabled = false

    private init() {}

    func configure(cloudKitEnabled: Bool) {
        isCloudKitEnabled = cloudKitEnabled
        if !cloudKitEnabled {
            pendingTask?.cancel()
            pendingTask = nil
        }
    }

    /// Schedules a debounced `context.save()` when CloudKit sync is enabled; saves immediately otherwise.
    func scheduleSave(_ context: ModelContext, label: String) throws {
        guard context.hasChanges else { return }
        guard isCloudKitEnabled else {
            try RepositoryHelpers.saveImmediately(context, contextLabel: label)
            return
        }

        pendingTask?.cancel()
        pendingTask = Task { @MainActor in
            try? await Task.sleep(for: debounceInterval)
            guard !Task.isCancelled else { return }
            do {
                try RepositoryHelpers.saveImmediately(context, contextLabel: label)
            } catch {
                StretheoLog.swiftData.error("Debounced save failed (\(label)): \(error.localizedDescription)")
            }
        }
    }

    func flushPendingSave(_ context: ModelContext, label: String) throws {
        pendingTask?.cancel()
        pendingTask = nil
        try RepositoryHelpers.saveImmediately(context, contextLabel: label)
    }
}
