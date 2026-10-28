//
//  BackupWalletZcashView.swift
//  CapsizedVault
//
//  Zcash counterpart to BackupWalletMainView — kept as a sibling rather than generalized into
//  it, since the two coins' backup data shapes (polyseed/legacy/keys vs. a single seed or a
//  multi-UFVK list) diverge enough that one shared view would branch almost every section on
//  the coin anyway (same reasoning as ZcashAccountSwitchSheet vs AccountSwitchSheet).
//

import SwiftUI
import QRCode

private enum ZcashBackupCopyStage: Equatable { case none, confirm, status, cleared }

struct BackupWalletZcashView: View {

    @Binding var isPresented: Bool
    @ObservedObject var activeWallet: ZECWallet
    var onBackedUp: (() -> Void)? = nil

    @Environment(\.scenePhase) private var scenePhase

    @StateObject private var authManager = AuthManager.shared
    @State private var hasAuthenticated = false
    @State private var hasRequestedAuthentication = false
    @State private var showingPINAuthentication = false
    @State private var pinErrorMessage: String?

    @State private var viewingKeys: [(label: String, ufvk: String, isAddedViewingKey: Bool)] = []
    @State private var seedRevealed = false
    @State private var qrOpen = false

    @State private var copyStage: ZcashBackupCopyStage = .none
    @State private var countdownSeconds = 30
    @State private var copiedField: String? = nil

    private var canShowBackup: Bool {
        !authManager.isAppLockEnabled || hasAuthenticated
    }

    /// Only computed once authenticated — the seed is deliberately never kept resident on
    /// `ZECWallet` itself (see its Keychain-only-at-`activate()` comment), so this view
    /// shouldn't cache it in `@State` beyond its own lifetime either.
    private var seedWords: [String] {
        guard canShowBackup, !activeWallet.isWatchOnly,
              let data = KeychainHelper.zcashSeed(for: activeWallet.walletId),
              let text = String(data: data, encoding: .utf8) else { return [] }
        return text.components(separatedBy: " ")
    }

    var body: some View {
        Group {
            if canShowBackup {
                backupContent
            } else {
                lockedContent
            }
        }
        .sheet(isPresented: $showingPINAuthentication) {
            ZStack {
                Color.dsBackground.ignoresSafeArea()
                VStack(spacing: 0) {
                    HStack {
                        Button {
                            showingPINAuthentication = false
                            pinErrorMessage = nil
                            isPresented = false
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

                    PINEntryView(title: "Enter PIN", subtitle: "Confirm wallet backup", errorMessage: $pinErrorMessage) { pin in
                        if authManager.authenticateWithPIN(pin) {
                            showingPINAuthentication = false
                            pinErrorMessage = nil
                            hasAuthenticated = true
                        } else {
                            pinErrorMessage = "Incorrect PIN. Try again."
                        }
                    }
                }
            }
        }
        .onAppear {
            guard !hasRequestedAuthentication else { return }
            hasRequestedAuthentication = true
            Task { await authenticateForBackup() }
        }
        .task(id: hasAuthenticated) {
            guard hasAuthenticated, activeWallet.isWatchOnly else { return }
            viewingKeys = await activeWallet.viewingKeys()
        }
        .onChange(of: scenePhase) { phase in
            if phase == .background || phase == .inactive {
                seedRevealed = false
                qrOpen = false
            }
        }
    }

    // MARK: - Backup content

    private var backupContent: some View {
        ZStack {
            Color.dsBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                ZStack {
                    Text("Backup wallet")
                        .font(.system(size: 26, weight: .bold))
                        .foregroundStyle(Color.dsTextPrimary)

                    HStack {
                        Button {
                            isPresented = false
                        } label: {
                            ZStack {
                                Circle()
                                    .fill(Color.dsJadeSoft)
                                    .frame(width: 40, height: 40)
                                Image(systemName: "xmark")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(Color.dsAccentStrong)
                            }
                        }
                        Spacer()
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 18)

                ScrollView {
                    VStack(spacing: 0) {
                        if activeWallet.isWatchOnly {
                            viewingKeysTab
                        } else {
                            seedTab
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    .padding(.bottom, 32)
                }
            }

            if qrOpen {
                qrOverlay
            }

            if copyStage != .none {
                copyDialogOverlay
            }
        }
    }

    // MARK: - Seed tab

    private var seedTab: some View {
        VStack(alignment: .leading, spacing: 14) {
            BackupWarningBanner(text: "Anyone with this phrase can access and take your funds. Keep it private and offline.")

            Text("A 24-word phrase that restores this wallet's funds and transaction history.")
                .font(.system(size: 13))
                .foregroundStyle(Color.dsTextSecondary)
                .lineSpacing(2)

            HStack {
                Spacer()
                Button {
                    copyStage = .confirm
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "doc.on.doc")
                            .font(.system(size: 13, weight: .semibold))
                        Text("Copy seed phrase")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .foregroundStyle(Color.dsAccentStrong)
                }
            }

            seedRevealSection

            HStack(spacing: 8) {
                Text("Birthday Height:")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.dsTextTertiary)
                if let height = activeWallet.birthdayHeight {
                    Text("\(height)")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Color.dsTextPrimary)
                    Button {
                        quickCopy("\(height)", field: "height")
                    } label: {
                        Image(systemName: copiedField == "height" ? "checkmark" : "doc.on.doc")
                            .font(.system(size: 13))
                            .foregroundStyle(Color.dsAccentStrong)
                    }
                } else {
                    Text("Not set")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Color.dsTextPrimary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.top, 4)

            Text("Restoring this seed in Zodl or Zashi only recovers the first account — any other accounts in this wallet won't appear there.")
                .font(.system(size: 12))
                .foregroundStyle(Color.dsTextTertiary)
                .lineSpacing(2)

            HStack {
                Spacer()
                Button {
                    qrOpen = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "qrcode")
                            .font(.system(size: 15, weight: .semibold))
                        Text("Show QR")
                            .font(.system(size: 15, weight: .semibold))
                    }
                    .foregroundStyle(Color.white)
                    .frame(minWidth: 160)
                    .frame(height: 48)
                    .background(Color.dsAccent, in: RoundedRectangle(cornerRadius: 14))
                }
                Spacer()
            }
            .padding(.top, 6)
        }
    }

    @ViewBuilder
    private var seedRevealSection: some View {
        ZStack {
            SeedPhraseGrid(words: seedWords)
                .blur(radius: seedRevealed ? 0 : 4)
                .animation(.easeInOut(duration: 0.15), value: seedRevealed)
                .allowsHitTesting(seedRevealed)

            if !seedRevealed {
                Button {
                    revealSeed()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "eye.slash")
                            .font(.system(size: 16, weight: .medium))
                        Text("Tap to reveal")
                            .font(.system(size: 15, weight: .semibold))
                    }
                    .foregroundStyle(Color.dsAccentStrong)
                }
            }
        }
    }

    // MARK: - Viewing keys tab

    private var viewingKeysTab: some View {
        VStack(alignment: .leading, spacing: 10) {
            BackupWarningBanner(text: "Anyone with a viewing key can see that account's balance and incoming transactions.")

            Text("Every account's viewing key in this wallet, including any added later with \"Add viewing key\".")
                .font(.system(size: 13))
                .foregroundStyle(Color.dsTextSecondary)
                .lineSpacing(2)

            if viewingKeys.isEmpty {
                HStack {
                    Spacer()
                    ProgressView()
                        .tint(Color.dsAccentStrong)
                    Spacer()
                }
                .padding(.vertical, 24)
            } else {
                ForEach(viewingKeys, id: \.ufvk) { entry in
                    zcashKeyRow(label: entry.label, isAddedViewingKey: entry.isAddedViewingKey, value: entry.ufvk)
                }
            }
        }
    }

    private func zcashKeyRow(label: String, isAddedViewingKey: Bool, value: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Text(label.uppercased())
                    .font(.system(size: 11, weight: .bold))
                    .kerning(0.5)
                    .foregroundStyle(Color.dsTextTertiary)
                if isAddedViewingKey {
                    Text("Added key")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(Color.dsAccentStrong)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.dsJadeSoft)
                        .clipShape(Capsule())
                }
            }

            HStack(alignment: .top, spacing: 10) {
                Text(value)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(Color.dsTextPrimary)
                    .lineLimit(3)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Button {
                    quickCopy(value, field: value)
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: copiedField == value ? "checkmark" : "doc.on.doc")
                            .font(.system(size: 13))
                        Text(copiedField == value ? "Copied" : "Copy")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .foregroundStyle(Color.dsAccentStrong)
                    .animation(.easeInOut(duration: 0.2), value: copiedField)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(Color.dsSurface2, in: RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - QR overlay

    private var qrOverlay: some View {
        let qrString = "zcash-wallet:?seed=\(seedWords.joined(separator: "+"))"
        let qrDoc: QRCode.Document = {
            let doc = try! QRCode.Document(utf8String: qrString)
            doc.errorCorrection = .medium
            doc.design.foregroundColor(CGColor(srgbRed: 107/255, green: 122/255, blue: 42/255, alpha: 1))
            doc.design.backgroundColor(CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 1))
            doc.design.shape.onPixels = QRCode.PixelShape.RoundedPath(cornerRadiusFraction: 0.7, hasInnerCorners: true)
            doc.design.shape.eye = QRCode.EyeShape.RoundedRect()
            return doc
        }()

        return ZStack {
            Color(red: 27/255, green: 35/255, blue: 32/255)
                .opacity(0.7)
                .ignoresSafeArea()
                .blur(radius: 4)
                .onTapGesture { qrOpen = false }

            VStack(spacing: 16) {
                Text("SEED PHRASE")
                    .font(.system(size: 13, weight: .bold))
                    .kerning(0.4)
                    .foregroundStyle(Color.white.opacity(0.9))

                ZStack {
                    QRCodeDocumentUIView(document: qrDoc)
                        .frame(width: 260, height: 260)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .blur(radius: seedRevealed ? 0 : 14)
                        .animation(.easeInOut(duration: 0.15), value: seedRevealed)

                    if !seedRevealed {
                        Button {
                            revealSeed()
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "eye.slash")
                                    .font(.system(size: 16, weight: .medium))
                                Text("Tap to reveal")
                                    .font(.system(size: 15, weight: .semibold))
                            }
                            .foregroundStyle(Color.white)
                        }
                    }
                }

                Button {
                    copyStage = .confirm
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "doc.on.doc")
                            .font(.system(size: 14, weight: .medium))
                        Text("Copy")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .foregroundStyle(Color.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(Color.white.opacity(0.14), in: Capsule())
                }

                Text("Tap anywhere to close")
                    .font(.system(size: 13))
                    .foregroundStyle(Color.white.opacity(0.7))
            }
        }
    }

    // MARK: - Copy dialog

    private var copyDialogOverlay: some View {
        ZStack {
            Color.black.opacity(0.32)
                .ignoresSafeArea()
                .onTapGesture {
                    if copyStage == .confirm { dismissCopyDialog() }
                }

            VStack(spacing: 0) {
                switch copyStage {
                case .confirm:
                    copyConfirmContent
                case .status:
                    copyStatusContent
                case .cleared:
                    copyClearedContent
                case .none:
                    EmptyView()
                }
            }
            .padding(20)
            .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 20))
            .shadow(color: .black.opacity(0.22), radius: 20, x: 0, y: 8)
            .padding(24)
        }
    }

    private var copyConfirmContent: some View {
        VStack(spacing: 18) {
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.dsDanger)
                    .padding(.top, 1)
                Text("Copying your seed phrase to the clipboard is risky — other apps can potentially read it. It will be copied to this device only (not synced via iCloud), and the clipboard will auto-clear in \(Int(clipboardTTL)) seconds.")
                    .font(.dsBodyMD)
                    .foregroundStyle(Color.dsDanger)
            }

            VStack(spacing: 10) {
                Button {
                    performCopySeed()
                } label: {
                    Text("Copy (This Device Only)")
                        .font(.dsButtonLG)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color.dsAccent, in: RoundedRectangle(cornerRadius: 14))
                }

                Button {
                    dismissCopyDialog()
                } label: {
                    Text("Cancel")
                        .font(.dsBodyMD)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.dsTextTertiary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                }
            }
        }
    }

    private var copyStatusContent: some View {
        VStack(spacing: 0) {
            Text("Copied to this device")
                .font(.dsBodyLG)
                .fontWeight(.bold)
                .foregroundStyle(Color.dsTextPrimary)

            Text("Clipboard will be cleared in:")
                .font(.dsBodyMD)
                .foregroundStyle(Color.dsTextSecondary)
                .padding(.top, 10)

            Text("\(countdownSeconds)s")
                .font(.system(size: 32, weight: .bold, design: .monospaced))
                .foregroundStyle(Color.dsDanger)
                .padding(.top, 4)

            VStack(spacing: 10) {
                Button {
                    clearClipboard()
                    withAnimation { copyStage = .cleared }
                } label: {
                    Text("Clear Now")
                        .font(.dsButtonLG)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color.dsAccent, in: RoundedRectangle(cornerRadius: 14))
                }

                Button {
                    dismissCopyDialog()
                } label: {
                    Text("Close")
                        .font(.dsBodyMD)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.dsTextSecondary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.dsBorder, lineWidth: 1))
                }
            }
            .padding(.top, 18)
        }
    }

    private var copyClearedContent: some View {
        VStack(spacing: 8) {
            Text("Clipboard cleared")
                .font(.dsBodyLG)
                .fontWeight(.bold)
                .foregroundStyle(Color.dsAccentStrong)
            Text("The copied text has been removed from your clipboard.")
                .font(.dsBodyMD)
                .foregroundStyle(Color.dsTextSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, 8)
        .onAppear {
            Task {
                try? await Task.sleep(nanoseconds: 1_800_000_000)
                dismissCopyDialog()
            }
        }
    }

    // MARK: - Locked content

    private var lockedContent: some View {
        VStack(spacing: 0) {
            HStack {
                Button {
                    isPresented = false
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
            }
            .padding(.horizontal, 16)
            .padding(.top, 18)

            Spacer()

            VStack(spacing: 14) {
                Image(systemName: "lock")
                    .font(.system(size: 40))
                    .foregroundStyle(Color.dsTextTertiary)

                Text("Authentication Required")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(Color.dsTextPrimary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 28)

            Spacer()
        }
    }

    // MARK: - Actions

    private let clipboardTTL: TimeInterval = 30

    private func revealSeed() {
        seedRevealed = true
        onBackedUp?()
        Task {
            try? await Task.sleep(nanoseconds: 20_000_000_000)
            seedRevealed = false
        }
    }

    private func performCopySeed() {
        let text = seedWords.joined(separator: " ")
        UIPasteboard.general.setItems(
            [["public.utf8-plain-text": text]],
            options: [.localOnly: true, .expirationDate: Date().addingTimeInterval(clipboardTTL)]
        )
        countdownSeconds = Int(clipboardTTL)
        withAnimation { copyStage = .status }
        startCountdown()
        onBackedUp?()
    }

    private func startCountdown() {
        Task {
            while countdownSeconds > 0 {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                await MainActor.run {
                    countdownSeconds -= 1
                    if countdownSeconds <= 0, copyStage == .status {
                        withAnimation { copyStage = .cleared }
                    }
                }
            }
        }
    }

    private func clearClipboard() {
        UIPasteboard.general.items = []
    }

    private func dismissCopyDialog() {
        withAnimation { copyStage = .none }
    }

    private func quickCopy(_ text: String, field: String) {
        UIPasteboard.general.string = text
        copiedField = field
        Task {
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            await MainActor.run { copiedField = nil }
        }
    }

    private func authenticateForBackup() async {
        guard authManager.isAppLockEnabled else {
            hasAuthenticated = true
            return
        }
        guard authManager.isBiometricEnabled && authManager.isBiometricAvailable else {
            showingPINAuthentication = true
            return
        }
        let success = await authManager.evaluateBiometrics(reason: "Confirm wallet backup")
        if success {
            hasAuthenticated = true
        } else {
            showingPINAuthentication = true
        }
    }
}

// MARK: - Warning banner

private struct BackupWarningBanner: View {
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.dsDanger)
                .padding(.top, 1)
            Text(text)
                .font(.system(size: 13))
                .foregroundStyle(Color.dsDanger)
                .lineSpacing(2)
        }
        .padding(12)
        .background(Color.dsDanger.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
    }
}
