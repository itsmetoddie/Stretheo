//
//  StressWatchView.swift
//  StretheoWatch
//

import SwiftUI
import WatchKit

struct StressWatchView: View {
    @Environment(WatchStressModel.self) private var stressModel

    @State private var isMeasuring = false
    @ScaledMetric(relativeTo: .largeTitle) private var stressScoreSize: CGFloat = 48

    private var snapshot: WatchStressSnapshot {
        stressModel.snapshot
    }

    private var stressColor: Color {
        guard stressModel.hasData else { return .secondary }
        return WatchPalette.displayColor(for: snapshot.stressLevel)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    if stressModel.hasData {
                        VStack(spacing: 4) {
                            Text("\(snapshot.stressLevel)")
                                .font(.system(size: stressScoreSize, weight: .bold, design: .rounded))
                                .foregroundStyle(stressColor)

                            Text(WatchPalette.categoryTitle(snapshot.stressCategory))
                                .font(.caption)
                                .foregroundStyle(stressColor)

                            Text(snapshot.measuredAt.formatted(.relative(presentation: .named)))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        VStack(spacing: 4) {
                            Text("--")
                                .font(.system(size: stressScoreSize, weight: .bold, design: .rounded))
                                .foregroundStyle(.secondary)
                            Text("No reading yet")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Button {
                        triggerMeasurement()
                    } label: {
                        HStack(spacing: 6) {
                            if isMeasuring {
                                ProgressView()
                                    .scaleEffect(0.7)
                            } else {
                                Image(systemName: "waveform.path.ecg")
                            }
                            Text(isMeasuring ? "Measuring..." : "Measure")
                                .font(.body)
                                .fontWeight(.medium)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(stressColor == .secondary ? WatchPalette.primary : stressColor)
                    .disabled(isMeasuring)
                }
                .padding(.horizontal, 4)
            }
            .navigationTitle("Stress")
            .navigationBarTitleDisplayMode(.inline)
            .dynamicTypeSize(.large ... .accessibility3)
            .onAppear {
                stressModel.reloadFromStore()
            }
        }
    }

    private func triggerMeasurement() {
        guard !isMeasuring else { return }
        isMeasuring = true
        WKInterfaceDevice.current().play(.start)
        Task {
            await WatchHealthManager.shared.performMeasurementIfNeeded()
            await MainActor.run {
                stressModel.reloadFromStore()
                isMeasuring = false
                WKInterfaceDevice.current().play(.success)
            }
        }
    }
}
