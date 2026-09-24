//
//  EditProfileView.swift
//  Stretheo
//

import SwiftUI
import UIKit

private struct EditProfileFormState {
    var displayName: String = ""
    var email: String = ""
    var birthMonth: Int = 1
    var birthYear: Int = 1990
    var sex: ProfileSex = .other
}

struct EditProfileView: View {
    @Bindable var viewModel: SettingsViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var form = EditProfileFormState()

    private var currentYear: Int {
        Calendar.current.component(.year, from: Date())
    }

    private var birthYearRange: [Int] {
        Array((1940...currentYear).reversed())
    }

    var body: some View {
        Form {
            Section(String(localized: "settings.profile.section")) {
                TextField(String(localized: "settings.profile.name"), text: $form.displayName)
                    .textContentType(.name)
                    .autocorrectionDisabled()

                if showsEmailField {
                    TextField(String(localized: "settings.profile.email"), text: $form.email)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }
            }

            Section(String(localized: "settings.profile.calibration")) {
                Picker(String(localized: "settings.profile.birth_month"), selection: $form.birthMonth) {
                    ForEach(1...12, id: \.self) { month in
                        Text(monthName(month)).tag(month)
                    }
                }
                .pickerStyle(.menu)

                Picker(String(localized: "settings.profile.birth_year"), selection: $form.birthYear) {
                    ForEach(birthYearRange, id: \.self) { year in
                        Text(String(year)).tag(year)
                    }
                }
                .pickerStyle(.menu)

                Picker(String(localized: "settings.profile.sex"), selection: $form.sex) {
                    Text(String(localized: "settings.profile.sex.male")).tag(ProfileSex.male)
                    Text(String(localized: "settings.profile.sex.female")).tag(ProfileSex.female)
                    Text(String(localized: "settings.profile.sex.other")).tag(ProfileSex.other)
                }
                .pickerStyle(.menu)
            }
        }
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle(String(localized: "settings.edit_profile"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button(String(localized: "common.cancel")) {
                    dismiss()
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button(String(localized: "common.save")) {
                    saveAndDismiss()
                }
                .fontWeight(.semibold)
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") {
                    UIApplication.shared.sendAction(
                        #selector(UIResponder.resignFirstResponder),
                        to: nil,
                        from: nil,
                        for: nil
                    )
                }
            }
        }
        .task {
            if viewModel.profile == nil {
                await viewModel.reload()
            }
            loadFormFromProfile()
        }
    }

    private var showsEmailField: Bool {
        FeatureFlags.signInWithAppleEnabled && viewModel.isSignedIn
    }

    private func loadFormFromProfile() {
        guard let profile = viewModel.profile else { return }
        form = EditProfileFormState(
            displayName: profile.displayName,
            email: profile.email ?? "",
            birthMonth: profile.birthMonth,
            birthYear: profile.birthYear,
            sex: profile.sex
        )
    }

    private func saveAndDismiss() {
        if let profile = viewModel.profile {
            profile.displayName = form.displayName
            profile.email = form.email.isEmpty ? nil : form.email
            profile.birthMonth = min(max(form.birthMonth, 1), 12)
            profile.birthYear = form.birthYear
            profile.sex = form.sex
        }
        viewModel.saveProfile()
        dismiss()
    }

    private func monthName(_ month: Int) -> String {
        Calendar.current.monthSymbols[month - 1]
    }
}
