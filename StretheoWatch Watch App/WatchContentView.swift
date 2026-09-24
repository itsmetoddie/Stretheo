//
//  WatchContentView.swift
//  StretheoWatch
//

import SwiftUI

struct WatchContentView: View {
    var body: some View {
        TabView {
            StressWatchView()
                .tabItem {
                    Label("Stress", systemImage: "waveform.path.ecg")
                }

            MoodEntryWatchView()
                .tabItem {
                    Label("Mood", systemImage: "face.smiling")
                }
        }
        .tabViewStyle(.page(indexDisplayMode: .always))
    }
}
