//
//  AWRestoreMonero1TitleSeed.swift
//  CapsizedVault
//
//  Created by Dmitrij on 16/01/2026.
//

import SwiftUI
import CapsizedMoneroKit

struct AWRestoreMonero1SeedKeys: View {
    
    enum RestoreMethod: String, CaseIterable {
        case seed = "Seed Phrase"
        case keys = "Keys"
    }
    
    @Binding var isPresented: Bool
    let nextAction: () -> Void
    
    enum FocusedField {
        case primaryAddress, viewKey, spendKey
    }
    @FocusState private var focusedField: FocusedField?
    @State private var isSeedFieldFocused: Bool = false
    
    @State private var selectedMethod: RestoreMethod = .seed
    @State private var seedPhrase: String = ""
    @State private var restoreHeight: String = ""
    @State private var showSeedWarningAlert: Bool = false
    
    // Monero Keys
    @State private var primaryAddress: String = ""
    @State private var viewKey: String = ""
    @State private var spendKey: String = ""
    
    @EnvironmentObject var walletVM: AddWalletViewModel

    var body: some View {
        ZStack {
            Color.dsBackground.ignoresSafeArea()
            
            VStack(spacing: 0) {
                headerView
                
                ScrollView {
                    VStack(spacing: 0) {
                        tabSwitcher
                            .padding(.top, 4)
                        
                        if selectedMethod == .seed {
                            seedPhraseTab
                                .padding(.top, 24)
                        } else {
                            keysTab
                                .padding(.top, 24)
                        }
                        
                        if selectedMethod == .seed {
                            Text("You can add your passphrase on the next screen")
                                .font(.dsBodySM)
                                .foregroundColor(.dsTextTertiary)
                                .multilineTextAlignment(.center)
                                .padding(.top, 20)
                        }
                        
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
            let data = walletVM.restoreMoneroWalletData
            if data.isFromSeed {
                selectedMethod = .seed
                seedPhrase = data.seed ?? ""
            } else if data.publicAddress != nil {
                selectedMethod = .keys
                primaryAddress = data.publicAddress ?? ""
                viewKey = data.viewKey ?? ""
                spendKey = data.spendKey ?? ""
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
            if selectedMethod == .seed && seedValidationError != nil {
                showSeedWarningAlert = true
            } else {
                buttonNextAction()
            }
        } label: {
            Text("Next")
        }
        .buttonStyle(.dsPrimary)
        .disabled(!isFormValid)
        .opacity(isFormValid ? 1 : 0.5)
        .alert("Seed Phrase Errors", isPresented: $showSeedWarningAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Continue Anyway") {
                buttonNextAction()
            }
        } message: {
            Text("The seed phrase contains errors and the wallet may not be restored correctly.")
        }
    }
    
    // MARK: - Keyboard Accessory Bar

    private var keyboardAccessoryBar: some View {
        HStack {
            HStack(spacing: 24) {
                Button("Paste") {
                    if let clipboard = UIPasteboard.general.string {
                        if isSeedFieldFocused {
                            seedPhrase = clipboard
                        } else {
                            switch focusedField {
                            case .primaryAddress: primaryAddress = clipboard
                            case .viewKey: viewKey = clipboard
                            case .spendKey: spendKey = clipboard
                            case .none: break
                            }
                        }
                    }
                }
                Button("Clear") {
                    if isSeedFieldFocused {
                        seedPhrase = ""
                    } else {
                        switch focusedField {
                        case .primaryAddress: primaryAddress = ""
                        case .viewKey: viewKey = ""
                        case .spendKey: spendKey = ""
                        case .none: break
                        }
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
            Text("Seed Phrase (Legacy or Polyseed)")
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

            Text("Enter your Monero seed phrase (25 words for Legacy or 16 words for Polyseed)")
                .font(.dsBodySM)
                .foregroundColor(.dsTextTertiary)
            
            if let error = seedValidationError {
                Text(unrecognizedWords.isEmpty ? error : "Unrecognized words found")
                    .font(.dsBodySM)
                    .fontWeight(.semibold)
                    .foregroundColor(.dsDanger)
            }
            
            HStack {
                Spacer()
                let wordCount = seedPhrase.components(separatedBy: CharacterSet(charactersIn: " \u{3000}")).filter { !$0.isEmpty }.count
                Text("\(wordCount) words")
                    .font(.dsBodySM)
                    .fontWeight(.semibold)
                    .foregroundColor(
                        (wordCount == 25 || wordCount == 16) && unrecognizedWords.isEmpty
                            ? .dsAccent : .dsTextTertiary
                    )
            }
        }
    }
    
    // MARK: - Keys Tab

    private var keysTab: some View {
        VStack(spacing: 20) {
            keyFieldSection(
                label: "Primary Address",
                placeholder: "4…",
                text: $primaryAddress,
                focus: .primaryAddress,
                hint: addressValidationError ?? "Your Monero wallet address (starts with 4)",
                isError: addressValidationError != nil
            )
            keyFieldSection(
                label: "Private View Key",
                placeholder: "Enter private view key",
                text: $viewKey,
                focus: .viewKey,
                hint: viewKeyValidationError ?? "64-character hexadecimal key",
                isError: viewKeyValidationError != nil
            )
            keyFieldSection(
                label: "Private Spend Key",
                placeholder: "Enter private spend key",
                text: $spendKey,
                focus: .spendKey,
                hint: spendKeyValidationError ?? "64-character hexadecimal key",
                isError: spendKeyValidationError != nil
            )
        }
    }
    
    private func keyFieldSection(
        label: String,
        placeholder: String,
        text: Binding<String>,
        focus: FocusedField,
        hint: String,
        isError: Bool
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.dsBodyMD)
                .fontWeight(.semibold)
                .foregroundColor(.dsTextSecondary)
            
            TextField(placeholder, text: text)
                .focused($focusedField, equals: focus)
                .font(.dsMonoMD)
                .foregroundColor(.dsTextPrimary)
                .padding(.horizontal, 16)
                .frame(height: 48)
                .background(Color.dsSurfaceRaised)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(isError ? Color.dsDanger.opacity(0.6) : Color.dsBorder, lineWidth: 1)
                )
                .autocapitalization(.none)
                .autocorrectionDisabled()

            Text(hint)
                .font(.dsBodySM)
                .fontWeight(isError ? .semibold : .regular)
                .foregroundColor(isError ? .dsDanger : .dsTextTertiary)
        }
    }
    
    // MARK: - Seed Validation

    private var seedValidationError: String? {
        let trimmed = seedPhrase.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let wordCount = trimmed.components(separatedBy: CharacterSet(charactersIn: " \u{3000}")).filter { !$0.isEmpty }.count
        
        if wordCount > 25 {
            return "Too many words — seed must be 16 or 25 words"
        }
        if wordCount == 16 {
            let result = Kit.validatePolyseed(trimmed.decomposedStringWithCompatibilityMapping)
            return result.errorMessage
        }
        if wordCount == 25 {
            let result = Kit.validateLegacySeed(trimmed)
            return result.errorMessage
        }
        return nil
    }
    
    private var unrecognizedWords: Set<String> {
        let trimmed = seedPhrase.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        let wordCount = trimmed.components(separatedBy: CharacterSet(charactersIn: " \u{3000}")).filter { !$0.isEmpty }.count
        
        if wordCount == 16 {
            let result = Kit.validatePolyseed(trimmed.decomposedStringWithCompatibilityMapping)
            return result.unrecognizedWords
        }
        if wordCount == 25 {
            let result = Kit.validateLegacySeed(trimmed)
            return result.unrecognizedWords
        }
        return []
    }

    // MARK: - Key Restore Validation

    private var trimmedPrimaryAddress: String {
        primaryAddress.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var trimmedViewKey: String {
        viewKey.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var trimmedSpendKey: String {
        spendKey.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var addressValidationError: String? {
        guard selectedMethod == .keys, !trimmedPrimaryAddress.isEmpty else { return nil }
        guard Kit.isValid(address: trimmedPrimaryAddress, networkType: .mainnet) else {
            return "Enter a valid Monero mainnet primary address"
        }
        return nil
    }

    private var viewKeyValidationError: String? {
        keyValidationError(for: trimmedViewKey, label: "Private view key", isViewKey: true)
    }

    private var spendKeyValidationError: String? {
        keyValidationError(for: trimmedSpendKey, label: "Private spend key", isViewKey: false)
    }

    private var keysValidationError: String? {
        addressValidationError ?? viewKeyValidationError ?? spendKeyValidationError
    }

    private func keyValidationError(for key: String, label: String, isViewKey: Bool) -> String? {
        guard selectedMethod == .keys, !key.isEmpty else { return nil }
        guard addressValidationError == nil, !trimmedPrimaryAddress.isEmpty else { return nil }

        if let wallet2Error = Kit.keyValidationError(key: key, address: trimmedPrimaryAddress, isViewKey: isViewKey, networkType: .mainnet) {
            return "\(label): \(wallet2Error)"
        }
        return nil
    }
    
    // MARK: - Form Validation

    private var isFormValid: Bool {
        if selectedMethod == .seed {
            let wordCount = seedPhrase.components(separatedBy: CharacterSet(charactersIn: " \u{3000}")).filter { !$0.isEmpty }.count
            return wordCount == 16 || wordCount == 25
        } else {
            return !trimmedPrimaryAddress.isEmpty &&
                   !trimmedViewKey.isEmpty &&
                   !trimmedSpendKey.isEmpty &&
                   keysValidationError == nil
        }
    }
    
    // MARK: - Restore Function

    private func buttonNextAction() {
        if selectedMethod == .seed {
            walletVM.restoreMoneroWalletData.isFromSeed = true
            walletVM.restoreMoneroWalletData.seed = seedPhrase.trimmingCharacters(in: .whitespacesAndNewlines)
        } else {
            guard keysValidationError == nil else { return }

            walletVM.restoreMoneroWalletData.isFromSeed = false
            walletVM.restoreMoneroWalletData.publicAddress = trimmedPrimaryAddress
            walletVM.restoreMoneroWalletData.viewKey = trimmedViewKey
            walletVM.restoreMoneroWalletData.spendKey = trimmedSpendKey
        }
        nextAction()
    }
}


// MARK: - Highlighted Text Editor

private struct HighlightedTextEditor: UIViewRepresentable {
    @Binding var text: String
    let unrecognizedWords: Set<String>
    var onFocusChange: ((Bool) -> Void)?

    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.delegate = context.coordinator
        textView.font = .preferredFont(forTextStyle: .body)
        textView.backgroundColor = .clear
        textView.autocapitalizationType = .none
        textView.autocorrectionType = .no
        textView.spellCheckingType = .no
        textView.textContainerInset = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
        textView.textContainer.lineFragmentPadding = 0
        return textView
    }

    func updateUIView(_ textView: UITextView, context: Context) {
        context.coordinator.parent = self

        if textView.text != text {
            textView.text = text
        }
        applyHighlighting(to: textView)
    }

    private func applyHighlighting(to textView: UITextView) {
        let currentText = textView.text ?? ""
        let font = UIFont.preferredFont(forTextStyle: .body)

        let attributed = NSMutableAttributedString(string: currentText, attributes: [
            .font: font,
            .foregroundColor: UIColor.label
        ])

        if !unrecognizedWords.isEmpty && !currentText.isEmpty {
            let regex = try? NSRegularExpression(pattern: "\\S+")
            let fullRange = NSRange(location: 0, length: (currentText as NSString).length)
            let matches = regex?.matches(in: currentText, range: fullRange) ?? []
            for match in matches {
                let word = (currentText as NSString).substring(with: match.range).lowercased()
                if unrecognizedWords.contains(word) {
                    attributed.addAttributes([
                        .foregroundColor: UIColor.systemRed,
                        .underlineStyle: NSUnderlineStyle.single.rawValue,
                        .underlineColor: UIColor.systemRed
                    ], range: match.range)
                }
            }
        }

        let selectedRange = textView.selectedRange
        textView.attributedText = attributed
        textView.selectedRange = selectedRange
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UITextViewDelegate {
        var parent: HighlightedTextEditor

        init(_ parent: HighlightedTextEditor) {
            self.parent = parent
        }

        func textViewDidChange(_ textView: UITextView) {
            parent.text = textView.text
        }

        func textViewDidBeginEditing(_ textView: UITextView) {
            parent.onFocusChange?(true)
        }

        func textViewDidEndEditing(_ textView: UITextView) {
            parent.onFocusChange?(false)
        }
    }
}
