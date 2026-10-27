//
//  AWRestoreZcash1SeedKeys.swift
//  CapsizedVault
//

import SwiftUI
import HdWalletKit
import ZcashLightClientKit

struct AWRestoreZcash1SeedKeys: View {

    enum RestoreMethod: String, CaseIterable {
        case seed = "Seed Phrase"
        case viewOnly = "View-only"
    }

    @Binding var isPresented: Bool
    let nextAction: () -> Void

    enum FocusedField {
        case ufvk
    }
    @FocusState private var focusedField: FocusedField?
    @State private var isSeedFieldFocused: Bool = false

    @State private var selectedMethod: RestoreMethod = .seed
    @State private var seedPhrase: String = ""
    @State private var ufvk: String = ""

    @EnvironmentObject var walletVM: AddWalletViewModel

    private static let englishWordSet: Set<String> = Set(Mnemonic.wordList(for: .english).map { String($0).lowercased() })

    var body: some View {
        ZStack {
            Color.dsBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                headerView

                ScrollView {
                    VStack(spacing: 0) {
                        tabSwitcher
                            .padding(.top, 4)

                        Group {
                            switch selectedMethod {
                            case .seed:
                                seedPhraseTab
                            case .viewOnly:
                                viewOnlyTab
                            }
                        }
                        .padding(.top, 24)

                        Spacer(minLength: 32)

                        nextButton
                            .padding(.top, 24)
                            .padding(.bottom, 32)
                    }
                    .padding(.horizontal, 24)
                    .instantScrollViewTouches()
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            if focusedField != nil || isSeedFieldFocused {
                keyboardAccessoryBar
            }
        }
        .onAppear {
            let data = walletVM.restoreZcashWalletData
            if data.isViewOnly {
                selectedMethod = .viewOnly
                ufvk = data.ufvk ?? ""
            } else if !data.words.isEmpty {
                selectedMethod = .seed
                seedPhrase = data.words.joined(separator: " ")
            }
        }
        .onChange(of: selectedMethod) { method in
            if method == .seed {
                focusedField = nil
            } else {
                isSeedFieldFocused = false
            }
        }
        .onChange(of: focusedField) { field in
            if field != nil {
                isSeedFieldFocused = false
            }
        }
    }

    // MARK: - Header

    private var headerView: some View {
        ZStack {
            Text("Restore Wallet")
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

    // MARK: - Tab Switcher

    private var tabSwitcher: some View {
        HStack(spacing: 3) {
            ForEach(RestoreMethod.allCases, id: \.self) { method in
                Button {
                    selectedMethod = method
                } label: {
                    Text(method.rawValue)
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundColor(selectedMethod == method ? .dsTextPrimary : .dsTextTertiary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(selectedMethod == method ? Color.dsSurfaceRaised : Color.clear)
                        .clipShape(Capsule())
                        .shadow(
                            color: selectedMethod == method ? Color.black.opacity(0.08) : .clear,
                            radius: 4, x: 0, y: 1
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background(Color.dsSurfaceSunken)
        .clipShape(Capsule())
    }

    // MARK: - Next Button

    private var nextButton: some View {
        Button {
            buttonNextAction()
        } label: {
            Text("Next")
        }
        .buttonStyle(.dsPrimary)
        .disabled(!isFormValid)
        .opacity(isFormValid ? 1 : 0.5)
    }

    // MARK: - Keyboard Accessory Bar

    private var keyboardAccessoryBar: some View {
        HStack {
            HStack(spacing: 24) {
                Button("Paste") {
                    if let clipboard = UIPasteboard.general.string {
                        if isSeedFieldFocused {
                            seedPhrase = clipboard
                        } else if focusedField == .ufvk {
                            ufvk = clipboard
                        }
                    }
                }
                Button("Clear") {
                    if isSeedFieldFocused {
                        seedPhrase = ""
                    } else if focusedField == .ufvk {
                        ufvk = ""
                    }
                }
            }
            .font(.dsBodyLG)
            .foregroundColor(.dsAccentStrong)

            Spacer()

            Button("Done") {
                focusedField = nil
                isSeedFieldFocused = false
                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
            }
            .font(.system(size: 17, weight: .bold, design: .rounded))
            .foregroundColor(.dsAccentStrong)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
        .background(Color.dsSurface)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Color.dsBorder)
                .frame(height: 0.5)
        }
    }

    // MARK: - Seed Phrase Tab

    private var seedPhraseTab: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Seed Phrase")
                .font(.dsBodyMD)
                .fontWeight(.semibold)
                .foregroundColor(.dsTextSecondary)

            HighlightedTextEditor(text: $seedPhrase, unrecognizedWords: unrecognizedWords) {
                isSeedFieldFocused = $0
            }
            .frame(height: 150)
            .padding(14)
            .background(Color.dsSurfaceRaised)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(
                        unrecognizedWords.isEmpty ? Color.dsBorder : Color.dsDanger.opacity(0.6),
                        lineWidth: 1
                    )
            )

            Text("Enter your 24-word Zcash seed phrase (English only)")
                .font(.dsBodySM)
                .foregroundColor(.dsTextTertiary)

            if let error = seedValidationError {
                Text(error)
                    .font(.dsBodySM)
                    .fontWeight(.semibold)
                    .foregroundColor(.dsDanger)
            }

            HStack {
                Spacer()
                let wordCount = normalizedWords.count
                Text("\(wordCount) words")
                    .font(.dsBodySM)
                    .fontWeight(.semibold)
                    .foregroundColor(
                        wordCount == 24 && unrecognizedWords.isEmpty
                            ? .dsAccent : .dsTextTertiary
                    )
            }
        }
    }

    // MARK: - View-only Tab

    private var viewOnlyTab: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Unified Full Viewing Key")
                .font(.dsBodyMD)
                .fontWeight(.semibold)
                .foregroundColor(.dsTextSecondary)

            TextField("uview1…", text: $ufvk)
                .focused($focusedField, equals: .ufvk)
                .font(.dsMonoMD)
                .foregroundColor(.dsTextPrimary)
                .padding(.horizontal, 16)
                .frame(height: 48)
                .background(Color.dsSurfaceRaised)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(ufvkValidationError != nil ? Color.dsDanger.opacity(0.6) : Color.dsBorder, lineWidth: 1)
                )
                .autocapitalization(.none)
                .autocorrectionDisabled()

            Text(ufvkValidationError ?? "A unified full viewing key (starts with uview1)")
                .font(.dsBodySM)
                .fontWeight(ufvkValidationError != nil ? .semibold : .regular)
                .foregroundColor(ufvkValidationError != nil ? .dsDanger : .dsTextTertiary)

            Text("View-only wallets can't spend and may not show outgoing transactions.")
                .font(.dsBodySM)
                .foregroundColor(.dsTextTertiary)
                .padding(.top, 12)
        }
    }

    // MARK: - Seed Validation

    private var normalizedWords: [String] {
        seedPhrase.trimmingCharacters(in: .whitespacesAndNewlines)
            .components(separatedBy: CharacterSet(charactersIn: " \u{3000}"))
            .filter { !$0.isEmpty }
            .map { $0.lowercased() }
    }

    private var unrecognizedWords: Set<String> {
        guard !normalizedWords.isEmpty else { return [] }
        return Set(normalizedWords.filter { !Self.englishWordSet.contains($0) })
    }

    private var seedValidationError: String? {
        guard !seedPhrase.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        let words = normalizedWords
        if words.count > 24 {
            return "Too many words — seed must be 24 words"
        }
        guard words.count == 24 else { return nil }
        if !unrecognizedWords.isEmpty {
            return "Unrecognized words found"
        }
        do {
            try Mnemonic.validate(words: words)
            return nil
        } catch {
            return "Invalid seed phrase — please check for typos"
        }
    }

    // MARK: - UFVK Validation

    private var trimmedUfvk: String {
        ufvk.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var ufvkValidationError: String? {
        guard !trimmedUfvk.isEmpty else { return nil }
        let tool = DerivationTool(networkType: .mainnet)
        if tool.isValidUnifiedFullViewingKey(trimmedUfvk) {
            return nil
        }
        if tool.isValidUnifiedIncomingViewingKey(trimmedUfvk) {
            return "This is an incoming viewing key (uivk…); a full viewing key (uview1…) is required."
        }
        return "Enter a valid unified full viewing key"
    }

    // MARK: - Form Validation

    private var isFormValid: Bool {
        switch selectedMethod {
        case .seed:
            return normalizedWords.count == 24 && seedValidationError == nil
        case .viewOnly:
            return !trimmedUfvk.isEmpty && ufvkValidationError == nil
        }
    }

    // MARK: - Next

    private func buttonNextAction() {
        switch selectedMethod {
        case .seed:
            walletVM.restoreZcashWalletData.isViewOnly = false
            walletVM.restoreZcashWalletData.words = normalizedWords
            walletVM.restoreZcashWalletData.ufvk = nil
        case .viewOnly:
            walletVM.restoreZcashWalletData.isViewOnly = true
            walletVM.restoreZcashWalletData.ufvk = trimmedUfvk
            walletVM.restoreZcashWalletData.words = []
        }
        nextAction()
    }
}
