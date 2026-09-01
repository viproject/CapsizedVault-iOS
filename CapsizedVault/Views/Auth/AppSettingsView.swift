import SwiftUI

struct AppSettingsView: View {

    @StateObject private var authManager = AuthManager.shared
    @State private var showingSetupPIN = false
    @State private var showingChangePIN = false
    @State private var showingDisableConfirm = false
    @State private var showingPINDisable = false
    @State private var pinDisableErrorMessage: String?

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            header

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    // MARK: Security group
                    sectionLabel("Authentication")
                        .padding(.top, 20)

                    securityCard
                        .padding(.top, 8)

                    Text("When enabled, the app locks after 30 seconds in the background.")
                        .font(.system(size: 13, weight: .regular, design: .rounded))
                        .foregroundStyle(Color.dsTextTertiary)
                        .padding(.horizontal, 4)
                        .padding(.top, 10)

                    // MARK: Privacy group
                    sectionLabel("Privacy")
                        .padding(.top, 20)

                    privacyCard
                        .padding(.top, 8)

                    Text("When enabled, amounts are always hidden when the app opens or returns from the background. When disabled, amounts stay in whatever state you last set them to.")
                        .font(.system(size: 13, weight: .regular, design: .rounded))
                        .foregroundStyle(Color.dsTextTertiary)
                        .padding(.horizontal, 4)
                        .padding(.top, 10)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 28)
            }
        }
        .background(Color.dsBackground)
        .sheet(isPresented: $showingSetupPIN) {
            SetupPINView { }
        }
        .sheet(isPresented: $showingChangePIN) {
            ChangePINView()
        }
        .alert("Disable App Lock?", isPresented: $showingDisableConfirm) {
            Button("Disable", role: .destructive) {
                Task { await confirmDisable() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Your PIN will be removed and the app will no longer lock automatically.")
        }
        .sheet(isPresented: $showingPINDisable) {
            ZStack {
                Color.dsBackground.ignoresSafeArea()
                VStack(spacing: 0) {
                    HStack {
                        Button {
                            showingPINDisable = false
                            pinDisableErrorMessage = nil
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

                    PINEntryView(title: "Enter PIN", subtitle: "Confirm to disable App Lock", errorMessage: $pinDisableErrorMessage) { pin in
                        if authManager.authenticateWithPIN(pin) {
                            showingPINDisable = false
                            pinDisableErrorMessage = nil
                            authManager.disableAppLock()
                        } else {
                            pinDisableErrorMessage = "Incorrect PIN. Try again."
                        }
                    }
                }
            }
        }
    }

    private func confirmDisable() async {
        guard authManager.isBiometricEnabled && authManager.isBiometricAvailable else {
            showingPINDisable = true
            return
        }
        let success = await authManager.evaluateBiometrics(reason: "Confirm to disable App Lock")
        if success {
            authManager.disableAppLock()
        } else {
            showingPINDisable = true
        }
    }

    // MARK: - Layout

    private var header: some View {
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
            Text("Security")
                .font(.system(size: 19, weight: .bold, design: .rounded))
                .foregroundStyle(Color.dsTextPrimary)
            Spacer()
            Color.clear.frame(width: 36, height: 36)
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
        .padding(.bottom, 20)
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 13, weight: .bold, design: .rounded))
            .foregroundStyle(Color.dsTextTertiary)
    }

    // MARK: - Security card

    private var securityCard: some View {
        VStack(spacing: 0) {
            settingsRow(
                label: "App Lock",
                isLast: !authManager.isAppLockEnabled,
                toggle: Binding(
                    get: { authManager.isAppLockEnabled },
                    set: { newValue in
                        if newValue { showingSetupPIN = true }
                        else { showingDisableConfirm = true }
                    }
                )
            )

            if authManager.isAppLockEnabled {
                if authManager.isBiometricAvailable {
                    settingsRow(
                        label: authManager.biometricName,
                        isLast: false,
                        toggle: Binding(
                            get: { authManager.isBiometricEnabled },
                            set: { newValue in
                                if newValue {
                                    Task {
                                        let success = await authManager.evaluateBiometrics(
                                            reason: "Enable \(authManager.biometricName)"
                                        )
                                        authManager.isBiometricEnabled = success
                                    }
                                } else {
                                    authManager.isBiometricEnabled = false
                                }
                            }
                        )
                    )
                }

                changePINRow
            }
        }
        .background(Color.dsSurfaceRaised)
        .clipShape(RoundedRectangle(cornerRadius: 22))
        .overlay(
            RoundedRectangle(cornerRadius: 22)
                .stroke(Color.dsBorder, lineWidth: 1)
        )
    }

    // MARK: - Privacy card

    private var privacyCard: some View {
        settingsRow(
            label: "Amount hidden",
            isLast: true,
            toggle: Binding(
                get: { authManager.isAmountHiddenEnabled },
                set: { authManager.isAmountHiddenEnabled = $0 }
            )
        )
        .background(Color.dsSurfaceRaised)
        .clipShape(RoundedRectangle(cornerRadius: 22))
        .overlay(
            RoundedRectangle(cornerRadius: 22)
                .stroke(Color.dsBorder, lineWidth: 1)
        )
    }

    // MARK: - Row primitives

    private func settingsRow(label: String, isLast: Bool, toggle: Binding<Bool>) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.dsTextPrimary)
            Spacer()
            Toggle("", isOn: toggle)
                .labelsHidden()
                .tint(Color.dsAccent)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .overlay(alignment: .bottom) {
            if !isLast {
                Rectangle()
                    .fill(Color.dsBorder)
                    .frame(height: 1)
                    .padding(.leading, 16)
            }
        }
    }

    private var changePINRow: some View {
        Button {
            showingChangePIN = true
        } label: {
            HStack {
                Text("Change PIN")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.dsAccentStrong)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.dsAccentStrong)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
        }
    }
}
