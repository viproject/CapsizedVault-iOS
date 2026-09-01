//
//  AWNewMoneroSeed.swift
//  CapsizedVault
//
//  Created by Dmitrij on 24/12/2025.
//

import SwiftUI

// MARK: - File-level enums

fileprivate enum SeedCopyTarget { case seed, passphrase }
fileprivate enum SeedCopyStage: Equatable { case none, confirm, status, cleared }


// MARK: - Main View

struct AWNewMonero3SeedBackUp: View {

    let nextAction: () -> Void

    @State private var showMoreDetails = false
    @State private var seedRevealed = false
    @State private var passRevealed = false
    @State private var savedAck = false
    @State private var copyTarget: SeedCopyTarget? = nil
    @State private var copyStage: SeedCopyStage = .none
    @State private var countdownSeconds = 30

    @EnvironmentObject var walletVM: AddWalletViewModel

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: 20) {

                        // Title
                        Text("Important: Back Up Your Seed Phrase")
                            .font(.dsHeadingMD)
                            .multilineTextAlignment(.center)

                        // Warning banner
                        SeedWarningBanner {
                            Text("Your recovery seed phrase is the only way to restore your funds if you lose, replace, reset, or damage your device. ") +
                            Text("Anyone who obtains it can access and take your funds").bold() +
                            Text(", so keep it private and offline.")
                        }

                        // Details toggle
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                showMoreDetails.toggle()
                            }
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: showMoreDetails ? "chevron.up" : "chevron.down")
                                    .font(.system(size: 13, weight: .semibold))
                                if !showMoreDetails {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .font(.system(size: 12))
                                }
                                Text(showMoreDetails ? "Hide details" : "Show more details")
                                    .font(.dsBodyMD)
                                    .fontWeight(.semibold)
                            }
                            .foregroundStyle(Color.dsDanger)
                        }

                        if showMoreDetails {
                            detailsPanel
                        }

                        // Passphrase section (if applicable)
                        if !walletVM.newMoneroWalletData.passphrase.isEmpty {
                            VStack(alignment: .center, spacing: 14) {
                                SeedSectionTitle(label: "Passphrase Backup")

                                passphraseRevealSection

                                HStack {
                                    Spacer()
                                    Button {
                                        copyTarget = .passphrase
                                        copyStage = .confirm
                                    } label: {
                                        HStack(spacing: 6) {
                                            Image(systemName: "doc.on.doc")
                                                .font(.system(size: 13, weight: .semibold))
                                            Text("Copy Passphrase")
                                                .font(.dsBodyMD)
                                                .fontWeight(.semibold)
                                        }
                                        .foregroundStyle(Color.dsAccentStrong)
                                    }
                                }

                                SeedWarningBanner {
                                    Text("Warning: your passphrase is not stored anywhere and cannot be recovered. It creates a separate wallet from your seed phrase alone — losing the passphrase means permanent loss of these funds, even if your seed phrase is safe. Back it up in a location separate from your seed phrase and record it exactly, since it's case-sensitive.")
                                }
                            }

                            Divider()
                                .padding(.vertical, 2)
                        }

                        // Seed phrase section
                        VStack(alignment: .center, spacing: 14) {
                            SeedSectionTitle(label: "Seed Phrase Backup")

                            seedPhraseRevealSection

                            HStack {
                                Spacer()
                                Button {
                                    copyTarget = .seed
                                    copyStage = .confirm
                                } label: {
                                    HStack(spacing: 6) {
                                        Image(systemName: "doc.on.doc")
                                            .font(.system(size: 13, weight: .semibold))
                                        Text("Copy Seed Phrase")
                                            .font(.dsBodyMD)
                                            .fontWeight(.semibold)
                                    }
                                    .foregroundStyle(Color.dsAccentStrong)
                                }
                            }
                        }

                        Spacer(minLength: 24)
                    }
                    .padding()
                }

                // Bottom: acknowledgment checkbox + next button
                VStack(spacing: 0) {
                    Button {
                        withAnimation {
                            savedAck.toggle()
                            if savedAck { walletVM.newMoneroWalletData.backedUp = true }
                        }
                    } label: {
                        HStack(spacing: 10) {
                            SeedAckCheckbox(checked: savedAck)
                            Text("I've saved my seed phrase")
                                .font(.dsBodyMD)
                                .foregroundStyle(Color.dsTextPrimary)
                            Spacer()
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 14)
                    }

                    Button {
                        nextAction()
                    } label: {
                        Text("Next")
                            .font(.dsButtonLG)
                            .foregroundStyle(Color.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(Color.dsAccent, in: RoundedRectangle(cornerRadius: 18))
                    }
//                    .disabled(!savedAck)
//                    .opacity(savedAck ? 1 : 0.5)
                    .animation(.easeInOut(duration: 0.2), value: savedAck)
                    .padding(.horizontal)
                    .padding(.bottom)
                }
            }

            // Copy dialog overlay
            if copyStage != .none {
                copyDialogOverlay
            }
        }
    }

    // MARK: - Seed reveal

    private var seedPhraseRevealSection: some View {
        let words = (walletVM.newMoneroWalletData.seed ?? "").components(separatedBy: CharacterSet(charactersIn: " \u{3000}"))
        return ZStack {
            SeedPhraseGrid(words: words)
                .blur(radius: seedRevealed ? 0 : 4)
                .animation(.easeInOut(duration: 0.15), value: seedRevealed)
                .allowsHitTesting(seedRevealed)

            if !seedRevealed {
                Button {
                    seedRevealed = true
                    Task {
                        try? await Task.sleep(nanoseconds: 20_000_000_000)
                        seedRevealed = false
                    }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "eye.slash")
                            .font(.system(size: 16, weight: .medium))
                        Text("Tap to reveal")
                            .font(.dsBodyMD)
                            .fontWeight(.semibold)
                    }
                    .foregroundStyle(Color.dsAccentStrong)
                }
            }
        }
    }

    // MARK: - Passphrase reveal

    private var passphraseRevealSection: some View {
        ZStack {
            Text(walletVM.newMoneroWalletData.passphrase)
                .font(.system(size: 20, weight: .bold, design: .monospaced))
                .foregroundStyle(Color.dsTextPrimary)
                .multilineTextAlignment(.center)
                .padding(.vertical, 14)
                .padding(.horizontal, 20)
                .frame(maxWidth: .infinity)
                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14))
                .blur(radius: passRevealed ? 0 : 5)
                .animation(.easeInOut(duration: 0.15), value: passRevealed)
                .allowsHitTesting(passRevealed)

            if !passRevealed {
                Button {
                    passRevealed = true
                    Task {
                        try? await Task.sleep(nanoseconds: 20_000_000_000)
                        passRevealed = false
                    }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "eye.slash")
                            .font(.system(size: 16, weight: .medium))
                        Text("Tap to reveal")
                            .font(.dsBodyMD)
                            .fontWeight(.semibold)
                    }
                    .foregroundStyle(Color.dsAccentStrong)
                }
            }
        }
    }

    // MARK: - Details panel

    private var detailsPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Please read and follow these rules carefully:")
                .font(.dsBodyMD)
                .fontWeight(.bold)
                .foregroundStyle(Color.dsDanger)

            let rules = [
                "Write the seed phrase down and store it in a safe offline place.",
                "Keep the words in the exact order shown.",
                "Never type or paste your seed phrase into a website, browser, or any app other than this wallet — no legitimate service will ever ask for it.",
                "Do not save the phrase in screenshots, cloud storage, email, notes apps, or messaging apps.",
                "Never share your seed phrase with anyone. Anyone who has it can access your wallet and funds.",
                "This app cannot recover your wallet if the seed phrase is lost.",
            ]

            ForEach(rules, id: \.self) { rule in
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.dsDanger)
                        .padding(.top, 2)
                    Text(rule)
                        .font(.dsBodyMD)
                        .foregroundStyle(Color.dsDanger)
                }
            }
        }
        .padding(12)
        .background(Color.dsDanger.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Copy dialog overlay

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
            .background(Color.dsSurfaceRaised, in: RoundedRectangle(cornerRadius: 20))
            .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.dsTextTertiary, lineWidth: 1))
            .padding(24)
        }
    }

    private var copyConfirmContent: some View {
        let warningText = copyTarget == .passphrase
            ? "Copying your passphrase to the clipboard is risky — other apps can potentially read it. It will be copied to this device only (not synced via iCloud), and the clipboard will auto-clear in \(Int(clipboardTTL)) seconds."
            : "Copying your seed phrase to the clipboard is risky — other apps can potentially read it. It will be copied to this device only (not synced via iCloud), and the clipboard will auto-clear in \(Int(clipboardTTL)) seconds."
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

    // MARK: - Actions

    private let clipboardTTL: TimeInterval = 30

    private func performCopy() {
        let text: String
        switch copyTarget {
        case .seed: text = walletVM.newMoneroWalletData.seed ?? ""
        case .passphrase: text = walletVM.newMoneroWalletData.passphrase
        case .none: return
        }
        UIPasteboard.general.setItems(
            [["public.utf8-plain-text": text]],
            options: [.localOnly: true, .expirationDate: Date().addingTimeInterval(clipboardTTL)]
        )

        countdownSeconds = Int(clipboardTTL)
        withAnimation { copyStage = .status }
        startCountdown()
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
        copyTarget = nil
    }
}

// MARK: - Supporting Views

struct SeedWarningBanner<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 14))
                .foregroundStyle(Color.dsDanger)
                .padding(.top, 1)
            content
                .font(.dsBodyMD)
                .foregroundStyle(Color.dsDanger)
                .multilineTextAlignment(.leading)
        }
        .padding(12)
        .background(Color.dsDanger.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
    }
}

private struct SeedSectionTitle: View {
    let label: String

    var body: some View {
        Text(label)
            .font(.system(size: 18, weight: .semibold, design: .rounded))
            .underline()
            .frame(maxWidth: .infinity, alignment: .center)
    }
}

private struct SeedAckCheckbox: View {
    let checked: Bool

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6)
                .fill(checked ? Color.dsAccent : Color.clear)
                .frame(width: 22, height: 22)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(checked ? Color.clear : Color.dsTextTertiary, lineWidth: 1.5)
                )
            if checked {
                Image(systemName: "checkmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.white)
            }
        }
        .animation(.easeInOut(duration: 0.15), value: checked)
    }
}

struct SeedWordChip: View {
    let index: Int
    let word: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 5) {
            Text("\(index).")
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(Color.dsTextTertiary)
            Text(word)
                .font(.system(size: 16, weight: .semibold, design: .monospaced))
                .foregroundStyle(Color.dsTextPrimary)
        }
        .padding(.vertical, 9)
        .padding(.horizontal, 14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemBackground))
        )
    }
}

struct SeedPhraseFlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = computeRows(proposal: proposal, subviews: subviews)
        var height: CGFloat = 0
        for (i, row) in rows.enumerated() {
            let rowHeight = row.map { $0.sizeThatFits(.unspecified).height }.max() ?? 0
            height += rowHeight
            if i < rows.count - 1 { height += spacing }
        }
        return CGSize(width: proposal.width ?? 0, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let rows = computeRows(proposal: proposal, subviews: subviews)
        var y = bounds.minY
        for row in rows {
            let rowHeight = row.map { $0.sizeThatFits(.unspecified).height }.max() ?? 0
            let rowWidth = row.reduce(0.0) { $0 + $1.sizeThatFits(.unspecified).width }
                + CGFloat(max(0, row.count - 1)) * spacing
            var x = bounds.minX + (bounds.width - rowWidth) / 2
            for subview in row {
                let size = subview.sizeThatFits(.unspecified)
                subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
                x += size.width + spacing
            }
            y += rowHeight + spacing
        }
    }

    private func computeRows(proposal: ProposedViewSize, subviews: Subviews) -> [[LayoutSubviews.Element]] {
        let maxWidth = proposal.width ?? .infinity
        var rows: [[LayoutSubviews.Element]] = [[]]
        var currentWidth: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if currentWidth + size.width > maxWidth && !rows[rows.count - 1].isEmpty {
                rows.append([])
                currentWidth = 0
            }
            rows[rows.count - 1].append(subview)
            currentWidth += size.width + spacing
        }
        return rows
    }
}

struct SeedPhraseGrid: View {
    let words: [String]

    var body: some View {
        SeedPhraseFlowLayout(spacing: 10) {
            ForEach(Array(words.enumerated()), id: \.offset) { index, word in
                SeedWordChip(index: index + 1, word: word)
            }
        }
    }
}
