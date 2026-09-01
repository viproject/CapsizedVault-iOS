//
//  RenameAccountView.swift
//  CapsizedVault
//
//  Rename-account sheet content.
//  Presented as a native .sheet from AccountSwitchSheet.
//

import SwiftUI

struct RenameAccountView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var accountLabel: String
    let onSave: (String) -> Void

    init(currentLabel: String, onSave: @escaping (String) -> Void) {
        _accountLabel = State(initialValue: currentLabel)
        self.onSave = onSave
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Rename account")
                .font(.dsHeadingMD)
                .foregroundStyle(Color.dsTextPrimary)
                .padding(.bottom, 16)

            Text("ACCOUNT TITLE")
                .font(.dsCaption)
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
                .font(.dsCaption)
                .foregroundStyle(Color.dsTextTertiary)
                .padding(.bottom, 20)

            Button("Save") {
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
