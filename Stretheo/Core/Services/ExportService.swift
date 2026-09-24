//
//  ExportService.swift
//  Stretheo
//

import Foundation
import UIKit

@MainActor
final class ExportService {
    private let dateFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    func exportCSV(measurements: [StressMeasurement], moods: [MoodEntry], from: Date, to: Date) throws -> URL {
        var lines = ["timestamp,stressLevel,category,triggerType,hrv,heartRate,respiratoryRate,sleepDuration,moodScore,moodWord"]

        for measurement in measurements {
            lines.append(measurementCSVRow(measurement))
        }
        for mood in moods {
            lines.append(moodCSVRow(mood))
        }

        let url = temporaryExportURL(extension: "csv")
        let header = "# Stretheo export \(dateFormatter.string(from: from)) – \(dateFormatter.string(from: to))\n"
        try (header + lines.joined(separator: "\n")).write(to: url, atomically: true, encoding: .utf8)
        PrivacyFileAttributes.applySensitiveFileProtection(at: url)
        return url
    }

    func exportPDF(measurements: [StressMeasurement], moods: [MoodEntry], from: Date, to: Date) throws -> URL {
        let title = String(localized: "export.pdf.title")
        let rangeText = String(localized: "export.pdf.range")
        let measurementsText = String(localized: "export.pdf.measurements")
        let moodsText = String(localized: "export.pdf.moods")

        let summary = """
        \(title)
        \(rangeText) \(from.formatted(date: .abbreviated, time: .omitted)) – \(to.formatted(date: .abbreviated, time: .omitted))
        \(measurementsText) \(measurements.count)
        \(moodsText) \(moods.count)
        """

        let measurementLines = measurements.prefix(40).map { measurement in
            "\(dateFormatter.string(from: measurement.measuredAt)) — \(measurement.stressLevel) (\(measurement.stressCategory.rawValue))"
        }
        let moodLines = moods.prefix(40).map { entry in
            let word = entry.moodWord.map { " (\($0))" } ?? ""
            return "\(dateFormatter.string(from: entry.entryDate)) — \(entry.moodScore)\(word)"
        }

        let body = ([summary, "", "Measurements:", ""] + measurementLines + ["", "Moods:", ""] + moodLines)
            .joined(separator: "\n")

        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: 612, height: 792))
        let url = temporaryExportURL(extension: "pdf")
        let attributes: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 12)]
        let paragraphHeight: CGFloat = 14
        let pageHeight: CGFloat = 792
        let margin: CGFloat = 40
        let textWidth: CGFloat = 532

        try renderer.writePDF(to: url, withActions: { context in
            var y: CGFloat = margin
            context.beginPage()
            for line in body.components(separatedBy: "\n") {
                if y + paragraphHeight > pageHeight - margin {
                    context.beginPage()
                    y = margin
                }
                let rect = CGRect(x: margin, y: y, width: textWidth, height: paragraphHeight * 2)
                line.draw(in: rect, withAttributes: attributes)
                y += paragraphHeight
            }
        })
        PrivacyFileAttributes.applySensitiveFileProtection(at: url)
        return url
    }

    // MARK: - CSV rows

    private func measurementCSVRow(_ measurement: StressMeasurement) -> String {
        let snap = measurement.healthSnapshot
        let heartRate = snap?.currentHeartRate ?? snap?.restingHeartRate
        return [
            csvField(dateFormatter.string(from: measurement.measuredAt)),
            csvField(String(measurement.stressLevel)),
            csvField(measurement.stressCategory.rawValue),
            csvField(measurement.triggerType.rawValue),
            csvField(optionalString(snap?.hrv)),
            csvField(optionalString(heartRate)),
            csvField(optionalString(snap?.respiratoryRate)),
            csvField(optionalString(snap?.sleepDuration)),
            "",
            ""
        ].joined(separator: ",")
    }

    private func moodCSVRow(_ mood: MoodEntry) -> String {
        [
            csvField(dateFormatter.string(from: mood.entryDate)),
            csvField(nil),
            csvField(nil),
            csvField(nil),
            csvField(nil),
            csvField(nil),
            csvField(nil),
            csvField(nil),
            csvField(String(mood.moodScore)),
            csvField(mood.moodWord)
        ].joined(separator: ",")
    }

    private func optionalString(_ value: Double?) -> String? {
        value.map { String($0) }
    }

    private func csvField(_ value: String?) -> String {
        guard let value, !value.isEmpty else { return "" }
        if value.contains(",") || value.contains("\"") || value.contains("\n") {
            return "\"\(value.replacingOccurrences(of: "\"", with: "\"\""))\""
        }
        return value
    }

    private func temporaryExportURL(extension ext: String) -> URL {
        // PRIVACY FIX: generic dated filename — no user name or device identifiers
        let day = exportFilenameDayFormatter.string(from: Date())
        return FileManager.default.temporaryDirectory
            .appendingPathComponent("stretheo-export-\(day).\(ext)")
    }

    private var exportFilenameDayFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }
}
