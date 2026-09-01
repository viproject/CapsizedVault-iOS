import SwiftUI
import LocalAuthentication

struct SetupPINView: View {

    var onComplete: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var step = Step.create
    @State private var firstPIN = ""
    @State private var errorMessage: String?

    private let authManager = AuthManager.shared

    private enum Step {
        case create, confirm, biometricPrompt
    }

    var body: some View {
        ZStack {
            Color.dsBackground.ignoresSafeArea()

            if step == .biometricPrompt {
                biometricOfferView
            } else {
                VStack(spacing: 0) {
                    shellHeader
                    stepIndicator
                    pinContent
                }
            }
        }
    }

    // MARK: - Shell

    private var shellHeader: some View {
        HStack {
            Button(action: { dismiss() }) {
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
            Text("Set Up PIN")
                .font(.system(size: 19, weight: .bold, design: .rounded))
                .foregroundStyle(Color.dsTextPrimary)
            Spacer()
            Color.clear.frame(width: 36, height: 36)
        }
        .padding(.horizontal, 16)
        .padding(.top, 36)
        .padding(.bottom, 8)
    }

    private var stepIndicator: some View {
        Text(step == .create ? "Step 1 of 2" : "Step 2 of 2")
            .font(.system(size: 13, weight: .medium, design: .rounded))
            .foregroundStyle(Color.dsTextTertiary)
    }

    @ViewBuilder
    private var pinContent: some View {
        switch step {
        case .create:
            PINEntryView(title: "Create PIN", subtitle: "Enter a 6-digit PIN", errorMessage: $errorMessage) { pin in
                firstPIN = pin
                errorMessage = nil
                step = .confirm
            }
        case .confirm:
            PINEntryView(title: "Confirm PIN", subtitle: "Re-enter your PIN", errorMessage: $errorMessage) { pin in
                if pin == firstPIN {
                    if authManager.enableAppLock(pin: pin) {
                        if authManager.isBiometricAvailable {
                            step = .biometricPrompt
                        } else {
                            onComplete()
                            dismiss()
                        }
                    }
                } else {
                    errorMessage = "PINs don't match. Try again."
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        firstPIN = ""
                        errorMessage = nil
                        step = .create
                    }
                }
            }
        case .biometricPrompt:
            EmptyView()
        }
    }

    // MARK: - Biometric offer

    private var biometricOfferView: some View {
        VStack(spacing: 0) {
            // Drag indicator
            RoundedRectangle(cornerRadius: 2)
                .fill(Color.dsTextPrimary.opacity(0.08))
                .frame(width: 36, height: 4)
                .padding(.top, 14)
                .padding(.bottom, 18)

            Spacer()

            // Icon + copy
            VStack(spacing: 16) {
                Image(systemName: authManager.biometricType == .faceID ? "faceid" : "touchid")
                    .font(.system(size: 56))
                    .foregroundStyle(Color.dsAccentStrong)

                Text("Enable \(authManager.biometricName)?")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(Color.dsTextPrimary)
                    .multilineTextAlignment(.center)

                Text("Unlock the app quickly with \(authManager.biometricName) instead of entering your PIN.")
                    .font(.system(size: 15))
                    .foregroundStyle(Color.dsTextTertiary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(6)
            }
            .padding(.horizontal, 20)

            Spacer()

            // Actions
            VStack(spacing: 14) {
                Button("Enable \(authManager.biometricName)") {
                    Task {
                        let success = await authManager.evaluateBiometrics(reason: "Enable \(authManager.biometricName)")
                        authManager.isBiometricEnabled = success
                        onComplete()
                        dismiss()
                    }
                }
                .buttonStyle(.dsPrimary)

                Button("Not Now") {
                    authManager.isBiometricEnabled = false
                    onComplete()
                    dismiss()
                }
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Color.dsAccentStrong.opacity(0.75))
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 28)
        }
    }
}
