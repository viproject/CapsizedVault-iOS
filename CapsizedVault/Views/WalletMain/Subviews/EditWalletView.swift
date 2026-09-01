//
//  EditWalletView.swift
//  CapsizedVault
//
//  Created by Dmitrij on 03/03/2026.
//

import SwiftUI

struct EditWalletView: View {
    @Binding var walletTitle: String
    var onSave: () -> Void

    @Environment(\.dismiss) private var dismiss
    @FocusState private var isFocused: Bool

    private var canSave: Bool {
        !walletTitle.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        ZStack {
            // Dimmed backdrop — tap to cancel
            Color(red: 27/255, green: 35/255, blue: 32/255)
                .opacity(0.25)
                .ignoresSafeArea()
                .onTapGesture { dismiss() }

            // Centered card
            VStack(alignment: .leading, spacing: 0) {

                // Title
                Text("Edit wallet")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(Color.dsTextPrimary)
                    .frame(maxWidth: .infinity, alignment: .center)

                // Helper
                Text("Update the title for this wallet.")
                    .font(.system(size: 13))
                    .foregroundStyle(Color.dsTextTertiary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 12)

                // Input
                TextField("", text: $walletTitle)
                    .font(.system(size: 15))
                    .foregroundStyle(Color.dsTextPrimary)
                    .padding(.horizontal, 12)
                    .frame(height: 42)
                    .background(Color.dsSurfaceRaised)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.dsBorder, lineWidth: 1)
                    )
                    .autocorrectionDisabled()
                    .focused($isFocused)
                    .padding(.top, 10)

                // Buttons
                HStack(spacing: 10) {
                    // Cancel
                    Button { dismiss() } label: {
                        Text("Cancel")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Color.dsAccentStrong)
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                            .background(Color.dsSurfaceRaised)
                            .clipShape(Capsule())
                            .overlay(Capsule().stroke(Color.dsBorder, lineWidth: 1))
                    }
                    .buttonStyle(.plain)

                    // Save
                    Button {
                        walletTitle = walletTitle.trimmingCharacters(in: .whitespaces)
                        onSave()
                    } label: {
                        Text("Save")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                            .background(Color.dsAccent.opacity(canSave ? 1 : 0.4))
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .disabled(!canSave)
                }
                .padding(.top, 18)
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 18)
            .frame(width: 300)
            .background(Color.dsSurface2)
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .shadow(color: .black.opacity(0.22), radius: 15, x: 0, y: 12)
        }
        .presentationBackground(.clear)
        .onAppear { isFocused = true }
    }
}
