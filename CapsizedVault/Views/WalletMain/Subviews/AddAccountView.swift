//
//  AddAccountView.swift
//  CapsizedVault
//
//  Create-new-account sheet content.
//  Presented as a native .sheet from AccountSwitchSheet.
//

import SwiftUI

struct AddAccountView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var accountLabel = ""
    let onSave: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("New account")
                .font(.system(size: 19, weight: .bold))
                .foregroundStyle(Color.dsTextPrimary)
                .padding(.bottom, 16)

            Text("ACCOUNT TITLE")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color.dsTextSecondary)
                .kerning(0.4)
                .padding(.bottom, 8)

            TextField("e.g. Savings", text: $accountLabel)
                .font(.system(size: 16))
                .padding(14)
                .background(Color.dsSurface2)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .autocorrectionDisabled()
                .padding(.bottom, 8)

            Text("This name is only visible to you.")
                .font(.system(size: 12))
                .foregroundStyle(Color.dsTextTertiary)
                .padding(.bottom, 20)

            Button("Create account") {
                let trimmed = accountLabel.trimmingCharacters(in: .whitespaces)
                guard !trimmed.isEmpty else { return }
                onSave(trimmed)
                dismiss()
            }
            .buttonStyle(.dsPrimary)
            .disabled(accountLabel.trimmingCharacters(in: .whitespaces).isEmpty)
        }
        .padding(.horizontal, 20)
        .padding(.top, 24)
        .padding(.bottom, 28)
    }
}
