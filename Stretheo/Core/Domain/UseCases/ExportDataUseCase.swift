//
//  ExportDataUseCase.swift
//  Stretheo
//

import Foundation

struct ExportDataUseCase {
    private let stressRepository: StressRepositoryProtocol
    private let moodRepository: MoodRepositoryProtocol
    private let exportLogRepository: ExportLogRepositoryProtocol
    private let exportService: ExportService

    init(
        stressRepository: StressRepositoryProtocol,
        moodRepository: MoodRepositoryProtocol,
        exportLogRepository: ExportLogRepositoryProtocol,
        exportService: ExportService
    ) {
        self.stressRepository = stressRepository
        self.moodRepository = moodRepository
        self.exportLogRepository = exportLogRepository
        self.exportService = exportService
    }

    @MainActor
    func execute(type: ExportType, from start: Date, to end: Date) throws -> URL {
        let measurements = try stressRepository.measurements(from: start, to: end, limit: 5000)
        let moods = try moodRepository.entries(from: start, to: end, limit: 5000)

        let url: URL
        switch type {
        case .csv:
            url = try exportService.exportCSV(measurements: measurements, moods: moods, from: start, to: end)
        case .pdf:
            url = try exportService.exportPDF(measurements: measurements, moods: moods, from: start, to: end)
        }

        _ = try exportLogRepository.log(exportType: type, from: start, to: end)
        return url
    }
}
