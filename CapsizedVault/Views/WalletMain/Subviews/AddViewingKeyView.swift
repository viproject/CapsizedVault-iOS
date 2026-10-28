//
//  AddViewingKeyView.swift
//  CapsizedVault
//
//  "Add viewing key" sheet content for a view-only Zcash wallet.
//  Presented as a native .sheet from ZcashAccountSwitchSheet.
//

import SwiftUI
import ZcashLightClientKit

struct AddViewingKeyView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var label = ""
    @State private var ufvk = ""
    @State private var useBirthdayDate = false
    @State private var birthdayDate = Date().addingYears(-1)
    let onSave: (String, String, Int?) -> Void

    private var trimmedUfvk: String {
        ufvk.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var ufvkValidationError: String? {
        guard !trimmedUfvk.isEmpty else { return nil }
        let tool = DerivationTool(networkType: .mainnet)
        if tool.isValidUnifiedFullViewingKey(trimmedUfvk) {
            return nil
        }
        if tool.isValidUnifiedIncomingViewingKey(trimmedUfvk) {
            return "This is an incoming viewing key (uivk…); a full viewing key (uview1…) is required."
        }
        return "Enter a valid unified full viewing key"
    }

    private var isFormValid: Bool {
        !label.trimmingCharacters(in: .whitespaces).isEmpty && !trimmedUfvk.isEmpty && ufvkValidationError == nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Add viewing key")
                .font(.dsHeadingMD)
                .foregroundStyle(Color.dsTextPrimary)
                .padding(.bottom, 16)

            Text("ACCOUNT TITLE")
                .font(.dsCaption)
                .foregroundStyle(Color.dsTextSecondary)
                .kerning(0.4)
                .padding(.bottom, 8)

            TextField("e.g. Savings", text: $label)
                .font(.system(size: 16))
                .padding(14)
                .background(Color.dsSurface2)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .autocorrectionDisabled()
                .padding(.bottom, 16)

            Text("UNIFIED FULL VIEWING KEY")
                .font(.dsCaption)
                .foregroundStyle(Color.dsTextSecondary)
                .kerning(0.4)
                .padding(.bottom, 8)

            TextEditor(text: $ufvk)
                .font(.system(size: 13, design: .monospaced))
                .frame(height: 90)
                .padding(10)
                .background(Color.dsSurface2)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)

            if let ufvkValidationError {
                Text(ufvkValidationError)
                    .font(.dsBodySM)
                    .foregroundStyle(Color.red)
                    .padding(.top, 6)
            }

            Toggle("I know this account's birthday", isOn: $useBirthdayDate)
                .font(.dsBodySM)
                .foregroundStyle(Color.dsTextSecondary)
                .padding(.top, 16)

            if useBirthdayDate {
                DatePicker("Birthday", selection: $birthdayDate, in: ...Date(), displayedComponents: .date)
                    .font(.dsBodySM)
                    .padding(.top, 4)
            } else {
                Text("Without a birthday, this account scans from Sapling activation (Oct 2018) — this can take a long time.")
                    .font(.dsBodySM)
                    .foregroundStyle(Color.dsTextTertiary)
                    .padding(.top, 6)
            }

            Button("Add viewing key") {
                let trimmedLabel = label.trimmingCharacters(in: .whitespaces)
                guard !trimmedLabel.isEmpty else { return }
                let birthday = useBirthdayDate ? ZcashBirthday.height(for: birthdayDate) : nil
                onSave(trimmedLabel, trimmedUfvk, birthday)
                dismiss()
            }
            .buttonStyle(.dsPrimary)
            .disabled(!isFormValid)
            .padding(.top, 20)
        }
        .padding(.horizontal, 20)
        .padding(.top, 24)
        .padding(.bottom, 28)
    }
}
