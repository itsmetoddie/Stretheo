//
//  SourceBadge.swift
//  Stretheo
//

import SwiftUI

struct SourceBadge: View {
    let triggerType: String

    private var normalized: String {
        triggerType.lowercased()
    }

    private var icon: String {
        switch normalized {
        case "manual":
            return "hand.tap"
        case "watch", "background", "automaticwatch":
            return "applewatch"
        default:
            return "arrow.clockwise"
        }
    }

    private var label: String {
        switch normalized {
        case "manual":
            return String(localized: "home.checkin.trigger.manual")
        case "watch", "automaticwatch":
            return String(localized: "home.checkin.trigger.watch")
        case "background", "auto", "automatic":
            return String(localized: "home.checkin.trigger.auto")
        default:
            return String(localized: "home.checkin.trigger.auto")
        }
    }

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: icon)
                .font(.caption2)
            Text(label)
                .font(.caption2)
                .fontWeight(.medium)
        }
        .foregroundStyle(.secondary)
    }
}
