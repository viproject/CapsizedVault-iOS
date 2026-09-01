import SwiftUI
import LocalAuthentication

struct LockScreenView: View {

    @StateObject private var authManager = AuthManager.shared
    @State private var showPIN = false
    @State private var errorMessage: String?
    @State private var showResetPIN = false
    @State private var showPasscodeRequiredAlert = false
    @State private var resetStep = ResetStep.create
    @State private var resetFirstPIN = ""
    @State private var resetError: String?

    private enum ResetStep {
        case create, confirm
    }

    var body: some View {
        ZStack {
            Color(.systemBackground)
                .ignoresSafeArea()

            if showResetPIN {
                resetPINView
            } else if showPIN {
                pinView
            } else {
                biometricPrompt
            }
        }
        .task {
            await attemptBiometric()
        }
        .alert("Device Passcode Required", isPresented: $showPasscodeRequiredAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("To reset your app PIN, set a passcode in iOS Settings → Face ID & Passcode.")
        }
    }

    private var biometricPrompt: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "lock.fill")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)

            Text("Capsized Vault is Locked")
                .font(.title3)
                .fontWeight(.semibold)

            if authManager.isBiometricEnabled && authManager.isBiometricAvailable {
                Button {
                    Task { await attemptBiometric() }
                } label: {
                    Label("Unlock with \(authManager.biometricName)", systemImage: biometricIcon)
                        .font(.headline)
                        .padding(.vertical, 14)
                        .padding(.horizontal, 24)
                        .background(Color.primary)
                        .foregroundStyle(Color(.systemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }

            Button("Use PIN") {
                showPIN = true
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)

            Spacer()
        }
    }

    private var pinView: some View {
        VStack {
            HStack {
                Button {
                    if authManager.isBiometricEnabled && authManager.isBiometricAvailable {
                        showPIN = false
                    }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .medium))
                }
                .opacity(authManager.isBiometricEnabled && authManager.isBiometricAvailable ? 1 : 0)
                Spacer()
            }
            .padding()

            PINEntryView(title: "Enter PIN", errorMessage: $errorMessage) { pin in
                if authManager.authenticateWithPIN(pin) {
                    errorMessage = nil
                } else {
                    errorMessage = "Incorrect PIN. Try again."
                }
            }

            Button("Forgot PIN?") {
                Task { await attemptPasscodeReset() }
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .padding(.bottom, 24)
        }
    }

    private var resetPINView: some View {
        VStack {
            HStack {
                Button {
                    showResetPIN = false
                    showPIN = true
                    resetStep = .create
                    resetFirstPIN = ""
                    resetError = nil
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .medium))
                }
                Spacer()
            }
            .padding()

            Group {
                switch resetStep {
                case .create:
                    PINEntryView(title: "Create New PIN", errorMessage: $resetError) { pin in
                        resetFirstPIN = pin
                        resetError = nil
                        resetStep = .confirm
                    }
                case .confirm:
                    PINEntryView(title: "Confirm New PIN", errorMessage: $resetError) { pin in
                        if pin == resetFirstPIN {
                            _ = authManager.resetPIN(pin)
                        } else {
                            resetError = "PINs don't match. Try again."
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                resetFirstPIN = ""
                                resetError = nil
                                resetStep = .create
                            }
                        }
                    }
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
        if authManager.isBiometricEnabled && authManager.isBiometricAvailable {
            let success = await authManager.authenticateWithBiometrics()
            if !success {
                showPIN = true
            }
        } else {
            showPIN = true
        }
    }

    private func attemptPasscodeReset() async {
        let context = LAContext()
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            showPasscodeRequiredAlert = true
            return
        }
        let success = await authManager.authenticateWithDevicePasscode()
        if success {
            showPIN = false
            showResetPIN = true
            resetStep = .create
            resetFirstPIN = ""
            resetError = nil
        }
    }
}
