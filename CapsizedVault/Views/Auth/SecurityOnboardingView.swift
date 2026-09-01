import SwiftUI

struct SecurityOnboardingView: View {

    @StateObject private var authManager = AuthManager.shared
    @State private var showSetupPIN = false
    @State private var skipped = false

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Color.dsBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // MARK: - Content block (icon + heading + body)
                VStack(spacing: 16) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color.dsAccent)
                            .frame(width: 72, height: 72)
                        Image(systemName: "lock.shield.fill")
                            .font(.system(size: 34))
                            .foregroundColor(.white)
                    }

                    Text("Secure your wallet")
                        .font(.dsHeadingLG)
                        .foregroundColor(.dsTextPrimary)

                    Text("Set up a PIN and optionally enable \(authManager.biometricName) to protect your funds.")
                        .font(.dsBodyLG)
                        .foregroundColor(.dsTextSecondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 300)
                }

                Spacer()

                // MARK: - Info banner (skipped state)
                if skipped {
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "info.circle")
                            .font(.system(size: 18))
                            .foregroundColor(.dsTextSecondary)
                        Text("You can enable this later in the Security settings.")
                            .font(.dsBodySM)
                            .foregroundColor(.dsTextSecondary)
                    }
                    .padding(.vertical, 14)
                    .padding(.horizontal, 16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.dsSurfaceSunken)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .padding(.bottom, 16)
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .offset(y: 6)),
                        removal: .opacity
                    ))
                }

                // MARK: - Button stack
                VStack(spacing: 12) {
                    if skipped {
                        Button {
                            authManager.markSecurityOnboardingShown()
                            dismiss()
                        } label: {
                            Text("Got it")
                        }
                        .buttonStyle(.dsPrimary)
                    } else {
                        Button {
                            showSetupPIN = true
                        } label: {
                            Text("Set up PIN")
                        }
                        .buttonStyle(.dsPrimary)

                        Button {
                            withAnimation(.easeInOut(duration: 0.18)) {
                                skipped = true
                            }
                        } label: {
                            Text("Skip for now")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(.dsAccentStrong)
                                .frame(maxWidth: .infinity)
                                .frame(height: 40)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.bottom, 20)
            }
            .padding(.horizontal, 24)
        }
        .sheet(isPresented: $showSetupPIN) {
            SetupPINView {
                authManager.markSecurityOnboardingShown()
                dismiss()
            }
        }
    }
}
