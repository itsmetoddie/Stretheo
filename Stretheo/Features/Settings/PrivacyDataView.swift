//
//  PrivacyDataView.swift
//  Stretheo
//

import SwiftUI

struct PrivacyDataView: View {
    @Bindable var viewModel: SettingsViewModel
    @AppStorage(AppSettingsKey.iCloudSyncEnabled) private var iCloudSyncEnabled = false
    @State private var exportType: ExportType = .csv
    @State private var exportStart = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
    @State private var exportEnd = Date()

    var body: some View {
        List {
            if FeatureFlags.iCloudCapabilityAvailable {
                Section(String(localized: "settings.privacy.icloud")) {
                    Toggle(String(localized: "settings.privacy.icloud.toggle"), isOn: $iCloudSyncEnabled)
                    Text(viewModel.iCloudStatus)
                        .font(AppTypography.metadata)
                        .foregroundStyle(.secondary)
                    Text(String(localized: "settings.privacy.icloud.footer"))
                        .font(AppTypography.metadata)
                }
            }
            Section(String(localized: "settings.privacy.export")) {
                Picker(String(localized: "export.format"), selection: $exportType) {
                    Text(String(localized: "export.pdf")).tag(ExportType.pdf)
                    Text(String(localized: "export.csv")).tag(ExportType.csv)
                }
                DatePicker(String(localized: "history.custom.start"), selection: $exportStart, displayedComponents: .date)
                DatePicker(String(localized: "history.custom.end"), selection: $exportEnd, displayedComponents: .date)
                Button(String(localized: "settings.privacy.export.action")) {
                    viewModel.exportData(type: exportType, from: exportStart, to: exportEnd)
                }
            }
            Section {
                DestructiveButton(title: String(localized: "settings.privacy.clear")) {
                    viewModel.showClearDataAlert = true
                }
                if FeatureFlags.signInWithAppleEnabled, viewModel.isSignedIn {
                    DestructiveButton(title: String(localized: "settings.privacy.delete_account")) {
                        viewModel.showDeleteAccountAlert = true
                    }
                }
            }
        }
        .navigationTitle(String(localized: "settings.privacy.title"))
        .alert(String(localized: "settings.privacy.clear.confirm.title"), isPresented: $viewModel.showClearDataAlert) {
            Button(String(localized: "common.cancel"), role: .cancel) {}
            Button(String(localized: "common.delete"), role: .destructive) { viewModel.clearAllData() }
        }
        .alert(String(localized: "settings.privacy.delete.confirm.title"), isPresented: $viewModel.showDeleteAccountAlert) {
            Button(String(localized: "common.cancel"), role: .cancel) {}
            Button(String(localized: "common.delete"), role: .destructive) { viewModel.deleteAccount() }
        }
    }

}
