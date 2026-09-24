//
//  WatchStressReadingHistory.swift
//  StretheoWatch
//
//  Recent stress levels on-device for consecutive-readings notification gate.
//

import Foundation

struct WatchStressReading: Codable, Sendable {
    let level: Int
    let measuredAt: TimeInterval
}

enum WatchStressReadingHistory {
    private static let fileName = "watch_stress_reading_history.json"
    private static let maxEntries = 10

    private static var fileURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return base.appendingPathComponent(fileName, isDirectory: false)
    }

    static func append(level: Int, measuredAt: Date) {
        var entries = loadEntries()
        entries.insert(
            WatchStressReading(level: level, measuredAt: measuredAt.timeIntervalSince1970),
            at: 0
        )
        if entries.count > maxEntries {
            entries = Array(entries.prefix(maxEntries))
        }
        saveEntries(entries)
    }

    static func recentLevels(limit: Int) -> [Int] {
        Array(loadEntries().prefix(limit).map(\.level))
    }

    static func clearAll() {
        try? FileManager.default.removeItem(at: fileURL)
    }

    private static func loadEntries() -> [WatchStressReading] {
        guard let data = try? Data(contentsOf: fileURL),
              let entries = try? JSONDecoder().decode([WatchStressReading].self, from: data) else {
            return []
        }
        return entries
    }

    private static func saveEntries(_ entries: [WatchStressReading]) {
        guard let data = try? JSONEncoder().encode(entries) else { return }
        let url = fileURL
        try? FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try? data.write(to: url, options: .atomic)
    }
}
