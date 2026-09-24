//
//  StretheoLog.swift
//  Stretheo
//

import OSLog

enum StretheoLog: Sendable {
    nonisolated static let subsystem = "com.zapreff.Stretheo"

    nonisolated static let healthKit = Logger(subsystem: subsystem, category: "HealthKit")
    nonisolated static let watchHealth = Logger(subsystem: subsystem, category: "WatchHealth")
    nonisolated static let watchConnectivity = Logger(subsystem: subsystem, category: "WatchConnectivity")
    nonisolated static let swiftData = Logger(subsystem: subsystem, category: "SwiftData")
    nonisolated static let stressRepository = Logger(subsystem: subsystem, category: "StressRepository")
    nonisolated static let background = Logger(subsystem: subsystem, category: "Background")
    nonisolated static let bgTask = Logger(subsystem: subsystem, category: "BGTask")
    nonisolated static let notification = Logger(subsystem: subsystem, category: "Notification")
    nonisolated static let measureStress = Logger(subsystem: subsystem, category: "MeasureStress")
    nonisolated static let privacy = Logger(subsystem: subsystem, category: "Privacy")
    nonisolated static let settings = Logger(subsystem: subsystem, category: "Settings")
    nonisolated static let history = Logger(subsystem: subsystem, category: "History")
    nonisolated static let rangeSwitch = Logger(subsystem: subsystem, category: "RangeSwitch")
    nonisolated static let historyPerf = Logger(subsystem: subsystem, category: "HistoryPerf")
}
