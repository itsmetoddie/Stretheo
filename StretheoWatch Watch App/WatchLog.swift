//
//  WatchLog.swift
//  StretheoWatch
//

import OSLog

enum StretheoLog: Sendable {
    nonisolated static let subsystem = "com.zapreff.Stretheo"
    nonisolated static let watchHealth = Logger(subsystem: subsystem, category: "WatchHealth")
    nonisolated static let watchConnectivity = Logger(subsystem: subsystem, category: "WatchConnectivity")
    nonisolated static let background = Logger(subsystem: subsystem, category: "Background")
}
