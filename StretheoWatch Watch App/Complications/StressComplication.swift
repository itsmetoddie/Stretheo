//
//  StressComplication.swift
//  StretheoWatch
//
//  WidgetKit complication — register via a Watch Widget Extension target with
//  `@main StretheoWatchWidgetBundle`, or embed per your Xcode watchOS template.
//

import SwiftUI
import WidgetKit

struct StressComplicationEntry: TimelineEntry {
    let date: Date
    let snapshot: WatchStressSnapshot
}

struct StressComplicationProvider: TimelineProvider {
    func placeholder(in context: Context) -> StressComplicationEntry {
        StressComplicationEntry(date: Date(), snapshot: WatchStressSnapshot(stressLevel: 42, stressCategory: "moderate", measuredAt: Date()))
    }

    func getSnapshot(in context: Context, completion: @escaping (StressComplicationEntry) -> Void) {
        completion(entry(for: Date()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<StressComplicationEntry>) -> Void) {
        let entry = entry(for: Date())
        let refresh = Date().addingTimeInterval(15 * 60)
        completion(Timeline(entries: [entry], policy: .after(refresh)))
    }

    private func entry(for date: Date) -> StressComplicationEntry {
        StressComplicationEntry(date: date, snapshot: WatchStressStore.load())
    }
}

struct StressComplicationWidget: Widget {
    static let kind = "StressComplication"

    let kind = Self.kind

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: StressComplicationProvider()) { entry in
            StressComplicationView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Stretheo Stress")
        .description("Your latest stress index from iPhone.")
        .supportedFamilies([
            .accessoryCircular,
            .accessoryRectangular,
            .accessoryCorner,
            .accessoryInline
        ])
    }
}

struct StressComplicationView: View {
    @Environment(\.widgetFamily) private var family
    let entry: StressComplicationEntry

    var body: some View {
        switch family {
        case .accessoryCircular:
            circularLayout
        case .accessoryRectangular:
            rectangularLayout
        case .accessoryCorner:
            cornerLayout
        case .accessoryInline:
            inlineLayout
        default:
            circularLayout
        }
    }

    private var circularLayout: some View {
        Gauge(value: gaugeValue) {
            Text("Stress")
        } currentValueLabel: {
            Text(levelText)
                .font(.headline.weight(.bold))
        }
        .gaugeStyle(.accessoryCircular)
        .tint(WatchPalette.color(for: entry.snapshot.stressCategory))
    }

    private var rectangularLayout: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Stretheo")
                    .font(.caption2.weight(.semibold))
                Text(levelText)
                    .font(.title3.weight(.bold))
                Text(WatchPalette.categoryTitle(entry.snapshot.stressCategory))
                    .font(.caption2)
                    .foregroundStyle(WatchPalette.color(for: entry.snapshot.stressCategory))
            }
            Spacer(minLength: 0)
            if entry.snapshot.hasData {
                Text(entry.snapshot.measuredAt, style: .time)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var cornerLayout: some View {
        Text(levelText)
            .font(.title3.weight(.bold))
            .foregroundStyle(WatchPalette.color(for: entry.snapshot.stressCategory))
    }

    private var inlineLayout: some View {
        Text("Stretheo \(levelText)")
            .font(.caption)
    }

    private var levelText: String {
        entry.snapshot.hasData ? "\(entry.snapshot.stressLevel)" : "—"
    }

    private var gaugeValue: Double {
        entry.snapshot.hasData ? Double(entry.snapshot.stressLevel) / 100 : 0
    }
}

/// Add a Watch Widget Extension target and set this bundle as `@main` there.
struct StretheoWatchWidgetBundle: WidgetBundle {
    var body: some Widget {
        StressComplicationWidget()
    }
}
