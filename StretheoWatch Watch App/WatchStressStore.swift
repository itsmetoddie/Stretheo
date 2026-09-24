//
//  WatchStressStore.swift
//  StretheoWatch
//
//  Latest Watch stress display snapshot — file-backed (not UserDefaults).
//

import Foundation

struct WatchStressSnapshot: Sendable, Equatable {
    var stressLevel: Int
    var stressCategory: String
    var measuredAt: Date

    static let empty = WatchStressSnapshot(stressLevel: 0, stressCategory: "low", measuredAt: .distantPast)

    var hasData: Bool {
        measuredAt != .distantPast && stressLevel > 0
    }

    init(stressLevel: Int, stressCategory: String, measuredAt: Date) {
        self.stressLevel = min(max(stressLevel, 0), 100)
        self.stressCategory = stressCategory
        self.measuredAt = measuredAt
    }

    init?(applicationContext: [String: Any]) {
        guard let level = applicationContext[WatchConnectivityPayloadKey.stressLevel.rawValue] as? Int else {
            return nil
        }
        let category = applicationContext[WatchConnectivityPayloadKey.category.rawValue] as? String ?? "low"
        let interval = applicationContext[WatchConnectivityPayloadKey.measuredAt.rawValue] as? TimeInterval ?? Date().timeIntervalSince1970
        self.init(stressLevel: level, stressCategory: category, measuredAt: Date(timeIntervalSince1970: interval))
    }

    var applicationContext: [String: Any] {
        [
            WatchConnectivityPayloadKey.stressLevel.rawValue: stressLevel,
            WatchConnectivityPayloadKey.category.rawValue: stressCategory,
            WatchConnectivityPayloadKey.measuredAt.rawValue: measuredAt.timeIntervalSince1970
        ]
    }
}

private struct WatchStressStorePayload: Codable {
    var stressLevel: Int
    var stressCategory: String
    var measuredAt: TimeInterval
}

enum WatchStressStore {
    private static let fileName = "watch_stress_snapshot.json"

    private static var fileURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return base.appendingPathComponent(fileName, isDirectory: false)
    }

    static func load() -> WatchStressSnapshot {
        guard let data = try? Data(contentsOf: fileURL),
              let payload = try? JSONDecoder().decode(WatchStressStorePayload.self, from: data) else {
            return .empty
        }
        return WatchStressSnapshot(
            stressLevel: payload.stressLevel,
            stressCategory: payload.stressCategory,
            measuredAt: Date(timeIntervalSince1970: payload.measuredAt)
        )
    }

    static func clearAll() {
        try? FileManager.default.removeItem(at: fileURL)
    }

    static func save(_ snapshot: WatchStressSnapshot) {
        let payload = WatchStressStorePayload(
            stressLevel: snapshot.stressLevel,
            stressCategory: snapshot.stressCategory,
            measuredAt: snapshot.measuredAt.timeIntervalSince1970
        )
        guard let data = try? JSONEncoder().encode(payload) else { return }
        let url = fileURL
        try? FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try? data.write(to: url, options: .atomic)
        // PRIVACY FIX: stress display cache is health-adjacent — protect on disk and skip backup
        PrivacyFileAttributes.applySensitiveFileProtection(at: url)
    }
}
