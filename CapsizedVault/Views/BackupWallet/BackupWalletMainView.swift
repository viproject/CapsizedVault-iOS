//
//  BackupWalletMainView.swift
//  CapsizedVault
//
//  Created by Dmitrij on 03/03/2026.
//

import SwiftUI
import QRCode

// MARK: - Enums

private enum BackupTab { case polyseed, keys, legacy }
private enum BackupCopyTarget { case seed, legacy, spendPrivate, viewPrivate }
private enum BackupCopyStage: Equatable { case none, confirm, status, cleared }

// MARK: - Main View

struct BackupWalletMainView: View {

    @Binding var isPresented: Bool

    @ObservedObject var activeWallet: XMRWallet
    var onBackedUp: (() -> Void)? = nil

    @Environment(\.scenePhase) private var scenePhase

    @StateObject private var authManager = AuthManager.shared
    @State private var selectedTab: BackupTab = .polyseed
    @State private var hasAuthenticated = false
    @State private var hasRequestedAuthentication = false
    @State private var showingPINAuthentication = false
    @State private var pinErrorMessage: String?

    // Reveal states
    @State private var seedRevealed = false
    @State private var legacyRevealed = false
    @State private var spendRevealed = false
    @State private var viewRevealed = false

    // QR overlay
    @State private var qrOpen = false

    // Copy dialog
    @State private var copyTarget: BackupCopyTarget = .seed
    @State private var copyStage: BackupCopyStage = .none
    @State private var countdownSeconds = 30

    // Inline copy feedback (public keys / address / restore height)
    @State private var copiedField: String? = nil

    // Tracks whether the initial tab selection has been made once data is available.
    // Without this, onAppear picks .keys (the only tab when data isn't ready yet),
    // and the onChange guard never re-selects because .keys is always present.
    @State private var tabInitialized = false

    private var canShowBackup: Bool {
        !authManager.isAppLockEnabled || hasAuthenticated
    }

    // Primary address is always derivable once the wallet file is open.
    // If it's nil the walletPointer hasn't been re-established yet (e.g. right
    // after a wallet switch that required re-opening the file on disk).
    private var isBackupDataAvailable: Bool {
        guard let addr = activeWallet.primaryAddress else { return false }
        return !addr.isEmpty
    }

    private var availableTabs: [BackupTab] {
        var tabs: [BackupTab] = []
        if !activeWallet.currentPolyseedArray.isEmpty { tabs.append(.polyseed) }
        if !activeWallet.currentLegacySeedArray.isEmpty { tabs.append(.legacy) }
        tabs.append(.keys)
        return tabs
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
            if isBackupDataAvailable {
                tabInitialized = true
                if let first = availableTabs.first { selectedTab = first }
            }
            guard !hasRequestedAuthentication else { return }
            hasRequestedAuthentication = true
            Task { await authenticateForBackup() }
        }
        .onChange(of: scenePhase) { phase in
            if phase == .background || phase == .inactive {
                seedRevealed = false
                legacyRevealed = false
                spendRevealed = false
                viewRevealed = false
                qrOpen = false
            }
        }
    }

    // MARK: - Backup Content

    private var backupContent: some View {
        ZStack {
            Color.dsBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
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

                    // Tab control — only shown when wallet data is ready
                    if isBackupDataAvailable {
                        if availableTabs.count > 1 {
                            BackupTabControl(
                                tabs: availableTabs,
                                selected: $selectedTab
                            )
                            .padding(.horizontal, 20)
                            .padding(.top, 20)
                        } else if let singleTab = availableTabs.first {
                            Text(singleTab.title)
                                .font(.system(size: 15, weight: .bold))
                                .foregroundStyle(Color.dsTextPrimary)
                                .padding(.horizontal, 20)
                                .padding(.top, 20)
                        }
                    }
                }

                if isBackupDataAvailable {
                    ScrollView {
                        VStack(spacing: 0) {
                            switch selectedTab {
                            case .polyseed:
                                polyseedTab
                            case .keys:
                                keysTab
                            case .legacy:
                                legacyTab
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 20)
                        .padding(.bottom, 32)
                    }
                } else {
                    walletLoadingView
                }
            }

            // QR Overlay
            if qrOpen {
                qrOverlay
            }

            // Copy dialog overlay
            if copyStage != .none {
                copyDialogOverlay
            }
        }
        .onChange(of: selectedTab) { _ in
            seedRevealed = false
            legacyRevealed = false
            spendRevealed = false
            viewRevealed = false
            qrOpen = false
        }
        // When the wallet finishes initializing its walletPointer (signalled by a
        // walletState change), select the first available tab the first time data
        // becomes ready. After that, user tab selections are left untouched.
        .onChange(of: activeWallet.walletState) { _ in
            guard isBackupDataAvailable, !tabInitialized else { return }
            tabInitialized = true
            if let first = availableTabs.first { selectedTab = first }
        }
    }

    // MARK: - Wallet Loading View

    private var walletLoadingView: some View {
        VStack(spacing: 12) {
            Spacer()
            ProgressView()
                .tint(Color.dsAccentStrong)
            Text("Wallet is initializing")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.dsTextPrimary)
            Text("Backup data will be available in a moment.")
                .font(.system(size: 13))
                .foregroundStyle(Color.dsTextSecondary)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .padding(.horizontal, 20)
    }

    // MARK: - Polyseed Tab

    private var polyseedTab: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Warning banner
            BackupWarningBanner(text: "Anyone with this phrase can access and take your funds. Keep it private and offline.")

            Text("A 16-word phrase that restores your wallet's funds and transaction history. Use this for everyday backups.")
                .font(.system(size: 13))
                .foregroundStyle(Color.dsTextSecondary)
                .lineSpacing(2)

            // Copy seed phrase link
            HStack {
                Spacer()
                Button {
                    copyTarget = .seed
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

            // Seed word grid with blur/reveal
            seedRevealSection(
                words: activeWallet.currentPolyseedArray,
                revealed: seedRevealed,
                onReveal: {
                    seedRevealed = true
                    Task {
                        try? await Task.sleep(nanoseconds: 20_000_000_000)
                        seedRevealed = false
                    }
                }
            )

            // Show QR button
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

    // MARK: - Keys Tab

    private var keysTab: some View {
        VStack(alignment: .leading, spacing: 10) {
            BackupWarningBanner(text: "Anyone with your private keys can access and take your funds. Keep them private and offline.")

            Text("Your raw address and cryptographic keys. Advanced use only — most backups should use seed phrase instead.")
                .font(.system(size: 13))
                .foregroundStyle(Color.dsTextSecondary)
                .lineSpacing(2)

            // Key rows
            BackupKeyRow(
                label: "PRIMARY ADDRESS",
                value: activeWallet.primaryAddress ?? "",
                isPrivate: false,
                revealed: true,
                copiedField: copiedField == "addr",
                onToggleReveal: nil,
                onCopy: { quickCopy(activeWallet.primaryAddress ?? "", field: "addr") }
            )
            BackupKeyRow(
                label: "SPEND KEY (PUBLIC)",
                value: activeWallet.spendKeyPublic ?? "",
                isPrivate: false,
                revealed: true,
                copiedField: copiedField == "spendPub",
                onToggleReveal: nil,
                onCopy: { quickCopy(activeWallet.spendKeyPublic ?? "", field: "spendPub") }
            )
            BackupKeyRow(
                label: "SPEND KEY (PRIVATE)",
                value: activeWallet.spendKeyPrivate ?? "",
                isPrivate: true,
                revealed: spendRevealed,
                copiedField: false,
                onToggleReveal: {
                    spendRevealed.toggle()
                    if spendRevealed {
                        Task {
                            try? await Task.sleep(nanoseconds: 20_000_000_000)
                            spendRevealed = false
                        }
                    }
                },
                onCopy: {
                    copyTarget = .spendPrivate
                    copyStage = .confirm
                }
            )
            BackupKeyRow(
                label: "VIEW KEY (PUBLIC)",
                value: activeWallet.viewKeyPublic ?? "",
                isPrivate: false,
                revealed: true,
                copiedField: copiedField == "viewPub",
                onToggleReveal: nil,
                onCopy: { quickCopy(activeWallet.viewKeyPublic ?? "", field: "viewPub") }
            )
            BackupKeyRow(
                label: "VIEW KEY (PRIVATE)",
                value: activeWallet.viewKeyPrivate ?? "",
                isPrivate: true,
                revealed: viewRevealed,
                copiedField: false,
                onToggleReveal: {
                    viewRevealed.toggle()
                    if viewRevealed {
                        Task {
                            try? await Task.sleep(nanoseconds: 20_000_000_000)
                            viewRevealed = false
                        }
                    }
                },
                onCopy: {
                    copyTarget = .viewPrivate
                    copyStage = .confirm
                }
            )

            // Restore height
            HStack(spacing: 8) {
                Text("Restore Height:")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.dsTextTertiary)
                Text(activeWallet.walletRestoreHeight.formatted())
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Color.dsTextPrimary)
                Button {
                    quickCopy("\(activeWallet.walletRestoreHeight)", field: "height")
                } label: {
                    Image(systemName: copiedField == "height" ? "checkmark" : "doc.on.doc")
                        .font(.system(size: 13))
                        .foregroundStyle(copiedField == "height" ? Color.dsAccentStrong : Color.dsAccentStrong)
                }
            }
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.top, 4)
        }
    }

    // MARK: - Legacy Tab

    private var legacyTab: some View {
        VStack(alignment: .leading, spacing: 14) {
            BackupWarningBanner(text: "Anyone with this phrase can access and take your funds. Keep it private and offline.")

            Text(availableTabs.contains(.polyseed)
                ? "A 25-word phrase in the original Monero format, for compatibility with older wallets. Use Polyseed unless you need this."
                : "A 25-word phrase in the original Monero format, for compatibility with older wallets."
            )
                .font(.system(size: 13))
                .foregroundStyle(Color.dsTextSecondary)
                .lineSpacing(2)

            // Copy seed phrase link
            HStack {
                Spacer()
                Button {
                    copyTarget = .legacy
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

            // Legacy seed word grid with blur/reveal
            seedRevealSection(
                words: activeWallet.currentLegacySeedArray,
                revealed: legacyRevealed,
                onReveal: {
                    legacyRevealed = true
                    Task {
                        try? await Task.sleep(nanoseconds: 20_000_000_000)
                        legacyRevealed = false
                    }
                }
            )

            // Restore height
            HStack(spacing: 8) {
                Text("Restore Height:")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.dsTextTertiary)
                Text(activeWallet.walletRestoreHeight.formatted())
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Color.dsTextPrimary)
                Button {
                    quickCopy("\(activeWallet.walletRestoreHeight)", field: "legacyHeight")
                } label: {
                    Image(systemName: copiedField == "legacyHeight" ? "checkmark" : "doc.on.doc")
                        .font(.system(size: 13))
                        .foregroundStyle(Color.dsAccentStrong)
                }
            }
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.top, 4)

            // Show QR button
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

    // MARK: - Seed Reveal Section

    @ViewBuilder
    private func seedRevealSection(words: [String], revealed: Bool, onReveal: @escaping () -> Void) -> some View {
        ZStack {
            SeedPhraseGrid(words: words)
                .blur(radius: revealed ? 0 : 4)
                .animation(.easeInOut(duration: 0.15), value: revealed)
                .allowsHitTesting(revealed)

            if !revealed {
                Button {
                    onReveal()
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

    // MARK: - QR Overlay

    private var qrOverlay: some View {
        let isLegacy = selectedTab == .legacy
        let words = isLegacy ? activeWallet.currentLegacySeedArray : activeWallet.currentPolyseedArray
        let tabRevealed = isLegacy ? legacyRevealed : seedRevealed
        let qrString: String = {
            let seed = words.joined(separator: "+")
            var s = "monero-wallet:?seed=\(seed)"
            if isLegacy { s += "&height=\(activeWallet.walletRestoreHeight)" }
            return s
        }()
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
                Text(isLegacy ? "LEGACY SEED" : "POLYSEED")
                    .font(.system(size: 13, weight: .bold))
                    .kerning(0.4)
                    .foregroundStyle(Color.white.opacity(0.9))

                ZStack {
                    QRCodeDocumentUIView(document: qrDoc)
                        .frame(width: 260, height: 260)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .blur(radius: tabRevealed ? 0 : 14)
                        .animation(.easeInOut(duration: 0.15), value: tabRevealed)

                    if !tabRevealed {
                        Button {
                            if isLegacy {
                                legacyRevealed = true
                                Task {
                                    try? await Task.sleep(nanoseconds: 20_000_000_000)
                                    legacyRevealed = false
                                }
                            } else {
                                seedRevealed = true
                                Task {
                                    try? await Task.sleep(nanoseconds: 20_000_000_000)
                                    seedRevealed = false
                                }
                            }
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
                    copyTarget = isLegacy ? .legacy : .seed
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

    // MARK: - Copy Dialog

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
        let warningText: String = {
            switch copyTarget {
            case .spendPrivate:
                return "Copying your private spend key to the clipboard is risky — other apps can potentially read it. It will be copied to this device only (not synced via iCloud), and the clipboard will auto-clear in \(Int(clipboardTTL)) seconds."
            case .viewPrivate:
                return "Copying your private view key to the clipboard is risky — other apps can potentially read it. It will be copied to this device only (not synced via iCloud), and the clipboard will auto-clear in \(Int(clipboardTTL)) seconds."
            default:
                return "Copying your seed phrase to the clipboard is risky — other apps can potentially read it. It will be copied to this device only (not synced via iCloud), and the clipboard will auto-clear in \(Int(clipboardTTL)) seconds."
            }
        }()

        return VStack(spacing: 18) {
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.dsDanger)
                    .padding(.top, 1)
                Text(warningText)
                    .font(.dsBodyMD)
                    .foregroundStyle(Color.dsDanger)
            }

            VStack(spacing: 10) {
                Button {
                    performCopy()
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

    // MARK: - Locked Content

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

    private func performCopy() {
        let text: String
        switch copyTarget {
        case .seed:    text = activeWallet.currentPolyseedArray.joined(separator: " ")
        case .legacy:  text = activeWallet.currentLegacySeedArray.joined(separator: " ")
        case .spendPrivate: text = activeWallet.spendKeyPrivate ?? ""
        case .viewPrivate:  text = activeWallet.viewKeyPrivate ?? ""
        }
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

// MARK: - Tab Control

private struct BackupTabControl: View {
    let tabs: [BackupTab]
    @Binding var selected: BackupTab

    private func label(for tab: BackupTab) -> String { tab.title }

    var body: some View {
        HStack(spacing: 2) {
            ForEach(tabs, id: \.self) { tab in
                Button {
                    withAnimation(.easeInOut(duration: 0.18)) { selected = tab }
                } label: {
                    Text(label(for: tab))
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(selected == tab ? Color.dsTextPrimary : Color.dsTextTertiary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 38)
                        .background {
                            if selected == tab {
                                Capsule()
                                    .fill(Color(.systemBackground))
                                    .shadow(color: .black.opacity(0.08), radius: 2, y: 1)
                            }
                        }
                }
            }
        }
        .padding(4)
        .background(Color.dsSurface2, in: Capsule())
    }
}

// MARK: - Warning Banner

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

// MARK: - Key Row

private struct BackupKeyRow: View {
    let label: String
    let value: String
    let isPrivate: Bool
    let revealed: Bool
    let copiedField: Bool
    let onToggleReveal: (() -> Void)?
    let onCopy: () -> Void

    private var displayValue: String {
        guard isPrivate && !revealed else { return value }
        return String(repeating: "•", count: 18)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Label row
            HStack(spacing: 4) {
                if isPrivate {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(Color.dsDanger)
                }
                Text(label)
                    .font(.system(size: 11, weight: .bold))
                    .kerning(0.5)
                    .foregroundStyle(isPrivate ? Color.dsDanger : Color.dsTextTertiary)
            }

            // Value + actions row
            HStack(alignment: .top, spacing: 10) {
                Text(displayValue)
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundStyle(Color.dsTextPrimary)
                    .lineLimit(3)
                    .frame(maxWidth: .infinity, alignment: .leading)

                HStack(spacing: 12) {
                    if isPrivate, let toggle = onToggleReveal {
                        Button(action: toggle) {
                            Image(systemName: revealed ? "eye.slash" : "eye")
                                .font(.system(size: 14))
                                .foregroundStyle(Color.dsTextTertiary)
                        }
                    }

                    Button(action: onCopy) {
                        HStack(spacing: 4) {
                            Image(systemName: copiedField ? "checkmark" : "doc.on.doc")
                                .font(.system(size: 13))
                            Text(copiedField ? "Copied" : "Copy")
                                .font(.system(size: 13, weight: .semibold))
                        }
                        .foregroundStyle(Color.dsAccentStrong)
                        .animation(.easeInOut(duration: 0.2), value: copiedField)
                    }
                }
                .padding(.top, 1)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(Color.dsSurface2, in: RoundedRectangle(cornerRadius: 16))
    }
}

extension BackupTab: Hashable {}
extension BackupTab {
    var title: String {
        switch self {
        case .polyseed: return "Polyseed"
        case .legacy:   return "Legacy"
        case .keys:     return "Keys"
        }
    }
}

