//
//  TransactionAuthView.swift
//  CapsizedVault
//
//  Pure move out of SendXMRSummaryView.swift so SendZECSummaryView can share it too — no
//  behavior change. PIN/biometric confirmation gate, no coin-specific logic.
//

import SwiftUI
import LocalAuthentication

struct TransactionAuthView: View {
    let onAuthenticated: () -> Void
    let onCancel: () -> Void

    @StateObject private var authManager = AuthManager.shared
    @State private var showPIN: Bool
    @State private var errorMessage: String?

    init(onAuthenticated: @escaping () -> Void, onCancel: @escaping () -> Void) {
        self.onAuthenticated = onAuthenticated
        self.onCancel = onCancel
        let hasBiometric = AuthManager.shared.isBiometricEnabled && AuthManager.shared.isBiometricAvailable
        _showPIN = State(initialValue: !hasBiometric)
    }

    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()
            if showPIN {
                pinView
            } else {
                biometricView
            }
        }
        .task {
            guard !showPIN else { return }
            await attemptBiometric()
        }
    }

    // MARK: Biometric view

    private var biometricView: some View {
        VStack(spacing: 24) {
            HStack {
                Spacer()
                Button("Cancel", action: onCancel)
                    .font(.body)
                    .foregroundStyle(Color.dsTextSecondary)
                    .padding()
            }

            Spacer()

            Image(systemName: "arrow.up.circle")
                .font(.system(size: 52))
                .foregroundStyle(Color.dsAccent)

            Text("Confirm Transaction")
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundStyle(Color.dsTextPrimary)

            Button {
                Task { await attemptBiometric() }
            } label: {
                Label("Use \(authManager.biometricName)", systemImage: biometricIcon)
                    .font(.headline)
                    .padding(.vertical, 14)
                    .padding(.horizontal, 24)
                    .background(Color.primary)
                    .foregroundStyle(Color(.systemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            Button("Use PIN") { showPIN = true }
                .font(.subheadline)
                .foregroundStyle(Color.dsTextSecondary)

            Spacer()
        }
    }

    // MARK: PIN view

    private var pinView: some View {
        VStack {
            HStack {
                Button {
                    if authManager.isBiometricEnabled && authManager.isBiometricAvailable {
                        showPIN = false
                    } else {
                        onCancel()
                    }
                } label: {
                    if authManager.isBiometricEnabled && authManager.isBiometricAvailable {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundStyle(Color.dsTextPrimary)
                    } else {
                        Text("Cancel")
                            .font(.body)
                            .foregroundStyle(Color.dsTextSecondary)
                    }
                }
                Spacer()
            }
            .padding()

            PINEntryView(title: "Enter PIN", errorMessage: $errorMessage) { pin in
                if KeychainHelper.verifyPIN(pin) {
                    errorMessage = nil
                    onAuthenticated()
                } else {
                    errorMessage = "Incorrect PIN. Try again."
                }
            }
        }
    }

    private var biometricIcon: String {
        switch authManager.biometricType {
        case .faceID: return "faceid"
        case .touchID: return "touchid"
        default: return "lock.shield"
        }
    }

    private func attemptBiometric() async {
        let success = await authManager.evaluateBiometrics(reason: "Confirm transaction")
        if success {
            onAuthenticated()
        } else {
            showPIN = true
        }
    }
}
