//
//  QuietHoursPicker.swift
//  Stretheo
//

import SwiftUI

struct QuietHoursPicker: View {
    @Binding var start: Date
    @Binding var end: Date

    var body: some View {
        DatePicker(String(localized: "settings.quiet.start"), selection: $start, displayedComponents: .hourAndMinute)
        DatePicker(String(localized: "settings.quiet.end"), selection: $end, displayedComponents: .hourAndMinute)
    }
}
