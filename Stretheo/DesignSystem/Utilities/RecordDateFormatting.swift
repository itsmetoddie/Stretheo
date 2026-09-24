//
//  RecordDateFormatting.swift
//  Stretheo
//

import Foundation

enum RecordDateFormatting {
    static func formatted(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return "Today " + date.formatted(.dateTime.hour().minute())
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday " + date.formatted(.dateTime.hour().minute())
        } else {
            return date.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated).hour().minute())
        }
    }
}
