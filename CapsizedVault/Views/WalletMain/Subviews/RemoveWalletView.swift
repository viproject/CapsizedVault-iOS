//
//  RemoveWalletView.swift
//  CapsizedVault
//
//  Created by Dmitrij on 03/03/2026.
//

import SwiftUI

struct RemoveWalletView: View {
    let walletTitle: String
    var onRemove: () -> Void
    var onCancel: () -> Void

    @StateObject private var authManager = AuthManager.shared
    @State private var showingConfirmAlert = false
    @State private var showingSuccessAlert = false
    @State private var showingPINAuthentication = false
    @State private var pinErrorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            // Title
            Text("Remove wallet")
                .font(.system(size: 19, weight: .bold))
                .foregroundStyle(Color.dsTextPrimary)
                .frame(maxWidth: .infinity, alignment: .center)

            // Warning card
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 16))
                    .foregroundStyle(Color.dsDanger)

                (Text(walletTitle).bold()
                 + Text(" will be removed from this device. Make sure you've backed up your recovery seed phrase — this action cannot be undone."))
                    .font(.system(size: 14))
                    .foregroundStyle(Color.dsDanger)
                    .lineSpacing(14 * 0.45)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.dsDanger.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .padding(.top, 20)

            // Action buttons
            VStack(spacing: 10) {
                Button {
                    showingConfirmAlert = true
                } label: {
                    Text("Remove wallet")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.dsDanger)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)

                Button(action: onCancel) {
                    Text("Cancel")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(Color.dsTextSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.plain)
            }
            .padding(.top, 20)
        }
        .padding(.horizontal, 20)
        .padding(.top, 14)
        .padding(.bottom, 28)
        .alert("Remove wallet?", isPresented: $showingConfirmAlert) {
            Button("Remove", role: .destructive) {
                Task { await confirmRemoval() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This action cannot be undone. Make sure you've backed up your recovery seed phrase.")
        }
        .alert("Wallet removed", isPresented: $showingSuccessAlert) {
            Button("Done") { onRemove() }
        } message: {
            Text("\(walletTitle) has been removed from this device.")
        }
        .sheet(isPresented: $showingPINAuthentication) {
            ZStack {
                Color.dsBackground.ignoresSafeArea()
                VStack(spacing: 0) {
                    HStack {
                        Button {
                            showingPINAuthentication = false
                            pinErrorMessage = nil
                        } label: {
                            ZStack {
                                Circle()
                                    .fill(Color.dsJadeSoft)
                                    .frame(width: 36, height: 36)
                                Image(systemName: "xmark")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(Color.dsAccentStrong)
                            }
                        }
                        Spacer()
                        Color.clear.frame(width: 36, height: 36)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 36)
                    .padding(.bottom, 8)

                    PINEntryView(title: "Enter PIN", subtitle: "Confirm wallet removal", errorMessage: $pinErrorMessage) { pin in
                        if authManager.authenticateWithPIN(pin) {
                            showingPINAuthentication = false
                            pinErrorMessage = nil
                            showingSuccessAlert = true
                        } else {
                            pinErrorMessage = "Incorrect PIN. Try again."
                        }
                    }
                }
            }
        }
    }

    private func confirmRemoval() async {
        guard authManager.isAppLockEnabled else {
            showingSuccessAlert = true
            return
        }

        guard authManager.isBiometricEnabled && authManager.isBiometricAvailable else {
            showingPINAuthentication = true
            return
        }

        let success = await authManager.evaluateBiometrics(reason: "Confirm wallet removal")
        if success {
            showingSuccessAlert = true
        } else {
            showingPINAuthentication = true
        }
    }
}
