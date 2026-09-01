//
//  AWNewMoneroTitle.swift
//  CapsizedVault
//
//  Created by Dmitrij on 19/12/2025.
//

import SwiftUI

struct AWNewMonero1Title: View {

    @Binding var isPresented: Bool
    let nextAction: () -> Void

    @State private var walletTitle: String = ""
    @State private var walletPassphrase: String = ""
    @State private var walletPassphraseRepeat: String = ""
    @State private var showPassphrase: Bool = false
    @State private var selectedSeedType: SeedType = .polyseed
    @State private var selectedPolyseedLanguage: PolyseedLanguage = .english
    @State private var selectedLegacyLanguage: LegacySeedLanguage = .english
    @State private var showSeedTypePicker: Bool = false
    @State private var showSeedLanguagePicker: Bool = false
    @FocusState private var titleFieldFocused: Bool

    @EnvironmentObject var walletVM: AddWalletViewModel

    private var currentLanguageDisplayName: String {
        selectedSeedType == .polyseed ? selectedPolyseedLanguage.displayName : selectedLegacyLanguage.displayName
    }

    var body: some View {
        ZStack {
            Color.dsBackground
                .ignoresSafeArea()

            VStack(spacing: 0) {
                headerView

                ScrollView {
                    VStack(spacing: 0) {
                        titleField
                            .padding(.top, 24)

                        seedPickerRows
                            .padding(.top, 16)

                        // Passphrase is only supported for Polyseed. For legacy seeds,
                        // the passphrase modifies the spend key in a way that makes the
                        // backup-view seed differ from the creation-screen seed, which
                        // would confuse users. Polyseed handles passphrases correctly.
                        if selectedSeedType == .polyseed {
                            passphraseToggleRow
                                .padding(.top, 12)

                            if showPassphrase {
                                passphraseFields
                                    .padding(.top, 16)
                                    .transition(.opacity.combined(with: .move(edge: .top)))
                            }
                        }

                        Spacer(minLength: 32)

                        createWalletButton
                            .padding(.top, 24)
                            .padding(.bottom, 32)
                    }
                    .padding(.horizontal, 24)
                    .instantScrollViewTouches()
                }
            }
        }
        .animation(.easeInOut(duration: 0.15), value: showPassphrase)
        .onChange(of: selectedSeedType) { type in
            if type == .legacy {
                showPassphrase = false
                walletPassphrase = ""
                walletPassphraseRepeat = ""
            }
        }
        .sheet(isPresented: $showSeedTypePicker) {
            SeedTypePickerSheet(selectedSeedType: $selectedSeedType)
                .presentationDetents([.fraction(0.35)])
                .presentationCornerRadius(26)
        }
        .sheet(isPresented: $showSeedLanguagePicker) {
            SeedLanguagePickerSheet(
                selectedSeedType: selectedSeedType,
                selectedPolyseedLanguage: $selectedPolyseedLanguage,
                selectedLegacyLanguage: $selectedLegacyLanguage
            )
            .presentationDetents([.fraction(0.6)])
            .presentationCornerRadius(26)
        }
    }

    // MARK: - Header

    private var headerView: some View {
        ZStack {
            Text("New Wallet")
                .font(.dsHeadingLG)
                .foregroundColor(.dsTextPrimary)

            HStack {
                Button {
                    isPresented = false
                } label: {
                    ZStack {
                        Circle()
                            .fill(Color.dsTextPrimary.opacity(0.08))
                            .frame(width: 36, height: 36)
                        Image(systemName: "xmark")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.dsTextPrimary)
                    }
                }
                .buttonStyle(.plain)
                Spacer()
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 16)
        .padding(.bottom, 12)
    }

    // MARK: - Title Field

    private var titleField: some View {
        TextField("Enter title …", text: $walletTitle)
            .font(.dsBodyLG)
            .foregroundColor(.dsTextPrimary)
            .autocorrectionDisabled()
            .textInputAutocapitalization(.words)
            .focused($titleFieldFocused)
            .padding(.horizontal, 16)
            .frame(height: 54)
            .background(Color.dsSurfaceRaised)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.dsAccent, lineWidth: 1.5)
            )
            .onAppear { titleFieldFocused = true }
    }

    // MARK: - Seed Picker Rows

    private var seedPickerRows: some View {
        VStack(spacing: 0) {
            Button {
                dismissKeyboard()
                showSeedTypePicker = true
            } label: {
                HStack {
                    Text("Seed Type")
                        .font(.dsBodyLG)
                        .foregroundColor(.dsTextPrimary)
                    Spacer()
                    Text("\(selectedSeedType.rawValue) (\(selectedSeedType.wordCount) words)")
                        .font(.dsBodyLG)
                        .fontWeight(.semibold)
                        .foregroundColor(.dsAccentStrong)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.dsAccentStrong)
                }
                .contentShape(Rectangle())
                .padding(.horizontal, 16)
                .frame(height: 52)
            }
            .buttonStyle(.plain)

            Rectangle()
                .fill(Color.ink900.opacity(0.08))
                .frame(height: 1)
                .padding(.horizontal, 16)

            Button {
                dismissKeyboard()
                showSeedLanguagePicker = true
            } label: {
                HStack {
                    Text("Seed Language")
                        .font(.dsBodyLG)
                        .foregroundColor(.dsTextPrimary)
                    Spacer()
                    Text(currentLanguageDisplayName)
                        .font(.dsBodyLG)
                        .fontWeight(.semibold)
                        .foregroundColor(.dsAccentStrong)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.dsAccentStrong)
                }
                .contentShape(Rectangle())
                .padding(.horizontal, 16)
                .frame(height: 52)
            }
            .buttonStyle(.plain)
        }
        .background(Color.dsSurfaceRaised)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Passphrase Toggle

    private var passphraseToggleRow: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Use Passphrase")
                    .font(.dsBodyLG)
                    .foregroundColor(.dsTextPrimary)
                Text("Optional")
                    .font(.dsBodySM)
                    .foregroundColor(.dsTextSecondary)
            }
            Spacer()
            Toggle("", isOn: $showPassphrase)
                .tint(.dsAccent)
                .labelsHidden()
                .onChange(of: showPassphrase) { _ in
                    dismissKeyboard()
                    walletPassphrase = ""
                    walletPassphraseRepeat = ""
                }
        }
        .padding(.horizontal, 16)
        .frame(height: 52)
        .background(Color.dsSurfaceRaised)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Passphrase Fields

    private var passphraseFields: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("A passphrase adds an extra word to your seed, creating a hidden wallet. Forgetting it means permanent loss of funds — it isn't stored anywhere and can't be recovered.")
                .font(.dsBodySM)
                .foregroundColor(.dsTextSecondary)
                .padding(.horizontal, 4)

            PassphraseActiveField(placeholder: "Enter Passphrase", text: $walletPassphrase)
            PassphraseUnfocusedField(
                placeholder: "Repeat Passphrase",
                text: $walletPassphraseRepeat,
                isEnabled: !walletPassphrase.isEmpty,
                hasError: isPassphraseMismatch
            )
            if isPassphraseMismatch {
                Text("Passphrases do not match")
                    .font(.dsBodySM)
                    .foregroundColor(.dsDanger)
                    .padding(.horizontal, 4)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    // MARK: - Create Wallet Button

    private var isTitleValid: Bool {
        !walletTitle.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private var isPassphraseMismatch: Bool {
        showPassphrase && !walletPassphraseRepeat.isEmpty && walletPassphrase != walletPassphraseRepeat
    }

    private var isPassphraseValid: Bool {
        guard showPassphrase else { return true }
        return !walletPassphrase.isEmpty && walletPassphrase == walletPassphraseRepeat
    }

    private var isCreateEnabled: Bool {
        isTitleValid && isPassphraseValid
    }

    private var createWalletButton: some View {
        Button {
            walletVM.newMoneroWalletData.title = walletTitle.trimmingCharacters(in: .whitespaces)
            walletVM.newMoneroWalletData.seedType = selectedSeedType
            walletVM.newMoneroWalletData.polyseedLanguage = selectedPolyseedLanguage
            walletVM.newMoneroWalletData.legacySeedLanguage = selectedLegacyLanguage
            if showPassphrase {
                walletVM.newMoneroWalletData.passphrase = walletPassphrase
            }
            nextAction()
        } label: {
            Text("Create Wallet")
                .font(.dsButtonLG)
                .foregroundColor(isCreateEnabled ? .white : .dsTextTertiary)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(isCreateEnabled ? Color.dsAccent : Color.dsSurfaceSunken)
                .clipShape(RoundedRectangle(cornerRadius: 18))
                .shadow(color: isCreateEnabled ? Color.dsAccent.opacity(0.35) : .clear, radius: 12, x: 0, y: 6)
        }
        .disabled(!isCreateEnabled)
    }

    // MARK: - Helpers

    private func dismissKeyboard() {
        titleFieldFocused = false
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }

    // MARK: - Validation

    private func validatePassphrase() -> Bool {
        guard showPassphrase else { return true }
        if walletPassphrase.isEmpty && walletPassphraseRepeat.isEmpty { return true }
        return walletPassphrase == walletPassphraseRepeat
    }
}

// MARK: - Passphrase Active Field

private struct PassphraseActiveField: View {
    let placeholder: String
    @Binding var text: String
    @State private var isSecured: Bool = true

    var body: some View {
        HStack {
            Image(systemName: "lock")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.dsAccentStrong)

            Group {
                if isSecured {
                    SecureField(placeholder, text: $text)
                } else {
                    TextField(placeholder, text: $text)
                }
            }
            .textContentType(.oneTimeCode)
            .autocorrectionDisabled()
            .textInputAutocapitalization(.never)
            .font(.dsBodyLG)
            .foregroundColor(.dsTextPrimary)

            Button { isSecured.toggle() } label: {
                Image(systemName: isSecured ? "eye.slash" : "eye")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.dsAccentStrong)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .frame(height: 54)
        .background(Color.dsSurfaceRaised)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.dsAccent, lineWidth: 1.5)
        )
    }
}

// MARK: - Passphrase Unfocused Field

private struct PassphraseUnfocusedField: View {
    let placeholder: String
    @Binding var text: String
    let isEnabled: Bool
    var hasError: Bool = false
    @State private var isSecured: Bool = true

    private var borderColor: Color {
        guard isEnabled else { return Color.ink900.opacity(0.08) }
        return hasError ? .dsDanger : .dsAccent
    }

    private var iconColor: Color {
        guard isEnabled else { return .dsTextTertiary }
        return hasError ? .dsDanger : .dsAccentStrong
    }

    var body: some View {
        HStack {
            Image(systemName: "lock")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(iconColor)

            Group {
                if isSecured {
                    SecureField(placeholder, text: $text)
                } else {
                    TextField(placeholder, text: $text)
                }
            }
            .textContentType(.oneTimeCode)
            .autocorrectionDisabled()
            .textInputAutocapitalization(.never)
            .font(.dsBodyLG)
            .foregroundColor(.dsTextPrimary)

            Button { isSecured.toggle() } label: {
                Image(systemName: isSecured ? "eye.slash" : "eye")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(iconColor)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .frame(height: 54)
        .background(isEnabled ? Color.dsSurfaceRaised : Color.dsSurfaceSunken)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(borderColor, lineWidth: isEnabled ? 1.5 : 1)
        )
        .disabled(!isEnabled)
        .animation(.easeInOut(duration: 0.15), value: isEnabled)
        .animation(.easeInOut(duration: 0.15), value: hasError)
    }
}

// MARK: - Seed Type Picker Sheet

private struct SeedTypePickerSheet: View {
    @Binding var selectedSeedType: SeedType
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            RoundedRectangle(cornerRadius: 2.5)
                .fill(Color.ink900.opacity(0.2))
                .frame(width: 36, height: 5)
                .padding(.top, 12)
                .padding(.bottom, 20)

            Text("SEED TYPE")
                .font(.dsCaption)
                .foregroundColor(.dsTextTertiary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 24)
                .padding(.bottom, 8)

            ForEach(SeedType.allCases) { type in
                Button {
                    selectedSeedType = type
                    dismiss()
                } label: {
                    HStack {
                        Text("\(type.rawValue) (\(type.wordCount) words)")
                            .font(.dsBodyLG)
                            .fontWeight(selectedSeedType == type ? .semibold : .regular)
                            .foregroundColor(selectedSeedType == type ? .dsAccentStrong : .dsTextPrimary)
                        Spacer()
                        if selectedSeedType == type {
                            Image(systemName: "checkmark")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.dsAccent)
                        }
                    }
                    .contentShape(Rectangle())
                    .padding(.horizontal, 24)
                    .frame(height: 52)
                    .background(selectedSeedType == type ? Color.dsAccent.opacity(0.08) : Color.clear)
                }
                .buttonStyle(.plain)
            }

            Spacer()
        }
        .background(Color.dsBackground.ignoresSafeArea())
    }
}

// MARK: - Seed Language Picker Sheet

private struct SeedLanguagePickerSheet: View {
    let selectedSeedType: SeedType
    @Binding var selectedPolyseedLanguage: PolyseedLanguage
    @Binding var selectedLegacyLanguage: LegacySeedLanguage
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            RoundedRectangle(cornerRadius: 2.5)
                .fill(Color.ink900.opacity(0.2))
                .frame(width: 36, height: 5)
                .padding(.top, 12)
                .padding(.bottom, 20)

            Text("SEED LANGUAGE")
                .font(.dsCaption)
                .foregroundColor(.dsTextTertiary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 24)
                .padding(.bottom, 8)

            ScrollView {
                if selectedSeedType == .polyseed {
                    ForEach(PolyseedLanguage.allCases) { lang in
                        Button {
                            selectedPolyseedLanguage = lang
                            dismiss()
                        } label: {
                            HStack {
                                Text(lang.displayName)
                                    .font(.dsBodyLG)
                                    .fontWeight(selectedPolyseedLanguage == lang ? .semibold : .regular)
                                    .foregroundColor(selectedPolyseedLanguage == lang ? .dsAccentStrong : .dsTextPrimary)
                                Spacer()
                                if selectedPolyseedLanguage == lang {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(.dsAccent)
                                }
                            }
                            .contentShape(Rectangle())
                            .padding(.horizontal, 24)
                            .frame(height: 52)
                            .background(selectedPolyseedLanguage == lang ? Color.dsAccent.opacity(0.08) : Color.clear)
                        }
                        .buttonStyle(.plain)
                    }
                } else {
                    ForEach(LegacySeedLanguage.allCases) { lang in
                        Button {
                            selectedLegacyLanguage = lang
                            dismiss()
                        } label: {
                            HStack {
                                Text(lang.displayName)
                                    .font(.dsBodyLG)
                                    .fontWeight(selectedLegacyLanguage == lang ? .semibold : .regular)
                                    .foregroundColor(selectedLegacyLanguage == lang ? .dsAccentStrong : .dsTextPrimary)
                                Spacer()
                                if selectedLegacyLanguage == lang {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(.dsAccent)
                                }
                            }
                            .contentShape(Rectangle())
                            .padding(.horizontal, 24)
                            .frame(height: 52)
                            .background(selectedLegacyLanguage == lang ? Color.dsAccent.opacity(0.08) : Color.clear)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .background(Color.dsBackground.ignoresSafeArea())
    }
}

#Preview {
    AWNewMonero1Title(isPresented: .constant(true), nextAction: {})
        .environmentObject(AddWalletViewModel())
}
