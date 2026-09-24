//
//  ExportLog.swift
//  Stretheo
//

import Foundation
import SwiftData

@Model
final class ExportLog {
    #Index<ExportLog>([\.createdAt])

    var id: UUID = UUID()
    var exportTypeRaw: String = ""
    var dateFrom: Date = Date()
    var dateTo: Date = Date()
    var createdAt: Date = Date()

    var userProfile: UserProfile?

    var exportType: ExportType {
        get { ExportType(rawValue: exportTypeRaw) ?? .csv }
        set { exportTypeRaw = newValue.rawValue }
    }

    init(
        id: UUID = UUID(),
        exportType: ExportType,
        dateFrom: Date,
        dateTo: Date,
        createdAt: Date = Date(),
        userProfile: UserProfile? = nil
    ) {
        self.id = id
        self.exportTypeRaw = exportType.rawValue
        self.dateFrom = dateFrom
        self.dateTo = dateTo
        self.createdAt = createdAt
        self.userProfile = userProfile
    }
}
