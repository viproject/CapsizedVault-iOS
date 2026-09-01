//
//  WalletMainView.swift
//  CapsizedVault
//

import SwiftUI
import RealmSwift
import CapsizedMoneroKit
import HsToolKit

private enum WalletSheetPending { case addWallet, restoreWallet }
private enum SettingsSheetPending { case security, nodes, backup, edit, remove }

struct WalletMainView: View {

    @StateObject private var walletManager = WalletManager.shared
    @StateObject private var priceManager = CoinPriceManager.shared
    @StateObject private var authManager = AuthManager.shared

    // Bottom sheet visibility
    @State private var showingAccountSheet = false
    @State private var showingWalletSheet = false
    @State private var showingSettingsSheet = false

    // Pending actions to fire after a sheet closes (avoids same-frame double-present)
    @State private var walletSheetPending: WalletSheetPending? = nil
    @State private var settingsSheetPending: SettingsSheetPending? = nil

    @Environment(\.scenePhase) private var scenePhase

    // Balance privacy toggle — persisted across launches; reset on foreground when amountHidden is on
    @AppStorage("balanceVisible") private var balanceVisible = false

    // Native sheet / full-screen cover flow state
    @State private var showingAddWallet = false
    @State private var showingRestoreWallet = false
    @State private var showingBackupWallet = false
    @State private var showingBackupAlert = false
    @State private var showingEditWallet = false
    @State private var showingRemoveWallet = false
    @State private var showingAppSettings = false
    @State private var showingNodeSettings = false
    @State private var showingReceiveXMR = false
    @State private var showingSendXMR = false
    @State private var selectedTransaction: TransactionInfo?
    @State private var labelInput = ""

    // Mac sidebar state (kept for reference)
    @State private var showingTitleAlert = false
    @State private var titleInput = ""

    private let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f
    }()
    private let shortDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .none
        return f
    }()

    // MARK: - Body

    var body: some View {
        Group {
            if let activeWallet = walletManager.activeWallet {
                mainContent(activeWallet)
            } else {
                OnboardingView(
                    onCreateWallet: { showingAddWallet = true },
                    onImportWallet: { showingRestoreWallet = true }
                )
            }
        }
        // --- Bottom sheets (native) ---
        .sheet(isPresented: $showingAccountSheet) {
            if let wallet = walletManager.activeWallet {
                AccountSwitchSheet(
                    wallet: wallet,
                    xmrPrice: priceManager.price(for: .monero, in: .usd),
                    balanceVisible: balanceVisible
                )
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(28)
                .presentationContentInteraction(.scrolls)
            }
        }
        .sheet(isPresented: $showingWalletSheet, onDismiss: {
            guard let action = walletSheetPending else { return }
            walletSheetPending = nil
            switch action {
            case .addWallet: showingAddWallet = true
            case .restoreWallet: showingRestoreWallet = true
            }
        }) {
            WalletSwitchSheet(
                walletManager: walletManager,
                xmrPrice: priceManager.price(for: .monero, in: .usd),
                balanceVisible: balanceVisible,
                onAddWallet: { walletSheetPending = .addWallet },
                onRestoreWallet: { walletSheetPending = .restoreWallet }
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
            .presentationCornerRadius(28)
            .presentationContentInteraction(.scrolls)
        }
        .sheet(isPresented: $showingSettingsSheet, onDismiss: {
            guard let action = settingsSheetPending else { return }
            settingsSheetPending = nil
            switch action {
            case .security: showingAppSettings = true
            case .nodes: showingNodeSettings = true
            case .backup: showingBackupWallet = true
            case .edit:
                labelInput = walletManager.activeWallet?.title ?? ""
                showingEditWallet = true
            case .remove: showingRemoveWallet = true
            }
        }) {
            let settingsSheet = SettingsSheet(
                onSecurity: { settingsSheetPending = .security },
                onNodes: { settingsSheetPending = .nodes },
                onBackup: { settingsSheetPending = .backup },
                onEditWallet: { settingsSheetPending = .edit },
                onRemoveWallet: { settingsSheetPending = .remove }
            )
            if UIDevice.current.userInterfaceIdiom == .pad {
                if #available(iOS 18.0, *) {
                    settingsSheet
                        .presentationSizing(.page)
                        .presentationDetents([.large])
                        .presentationDragIndicator(.visible)
                        .presentationCornerRadius(28)
                } else {
                    settingsSheet
                        .presentationDetents([.large])
                        .presentationDragIndicator(.visible)
                        .presentationCornerRadius(28)
                }
            } else {
                settingsSheet
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
                    .presentationCornerRadius(28)
            }
        }
        // --- Existing sheets & full-screen covers ---
        .fullScreenCover(isPresented: $showingAddWallet) {
            AddWalletMainView(isPresented: $showingAddWallet, currentWalletType: .moneroNew)
        }
        .fullScreenCover(isPresented: $showingRestoreWallet) {
            AddWalletMainView(isPresented: $showingRestoreWallet, currentWalletType: .moneroRestore)
        }
        .fullScreenCover(isPresented: $showingBackupWallet) {
            if let activeWallet = walletManager.activeWallet {
                BackupWalletMainView(isPresented: $showingBackupWallet, activeWallet: activeWallet, onBackedUp: {
                    walletManager.clearPendingSeedBackup(for: activeWallet)
                })
            }
        }
        .alert("Backup Required", isPresented: $showingBackupAlert) {
            Button("Open Backup") {
                showingBackupWallet = true
            }
            Button("I Already Have a Backup", role: .destructive) {
                if let wallet = walletManager.activeWallet {
                    walletManager.clearPendingSeedBackup(for: wallet)
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Save your seed phrase so you can always recover your wallet if your device is lost or reset.")
        }
        .fullScreenCover(isPresented: $showingEditWallet) {
            EditWalletView(walletTitle: $labelInput) {
                walletManager.updateActiveWalletTitle(labelInput)
                showingEditWallet = false
            }
        }
        .sheet(isPresented: $showingRemoveWallet) {
            RemoveWalletView(
                walletTitle: walletManager.activeWallet?.title ?? "",
                onRemove: {
                    showingRemoveWallet = false
                    walletManager.removeActiveWallet()
                },
                onCancel: { showingRemoveWallet = false }
            )
            .presentationDetents([.height(360)])
            .presentationDragIndicator(.visible)
            .presentationCornerRadius(28)
        }
        .sheet(isPresented: $showingAppSettings) {
            AppSettingsView()
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(20)
        }
        .sheet(isPresented: $showingNodeSettings) {
            NodeSettingsView()
                .presentationDetents([.fraction(0.86)])
                .presentationDragIndicator(.hidden)
                .presentationCornerRadius(28)
        }
        .sheet(isPresented: $showingReceiveXMR) {
            ReceiveXMRView()
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(20)
        }
        .sheet(isPresented: $showingSendXMR) {
            SendXMRView()
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(20)
        }
        .sheet(item: $selectedTransaction) { tx in
            TransactionDetailsView(
                transaction: tx,
                wallet: walletManager.activeWallet!
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
            .presentationCornerRadius(20)
        }
        .onChange(of: scenePhase) { phase in
            if (phase == .background || phase == .inactive) && authManager.isAmountHiddenEnabled {
                balanceVisible = false
            }
        }
        .task {
            // Force-hide amounts on cold launch when amount-hidden setting is on
            if authManager.isAmountHiddenEnabled {
                balanceVisible = false
            }
        }
    }

    // MARK: - Main content

    private func mainContent(_ wallet: XMRWallet) -> some View {
        let xmrPrice = priceManager.price(for: .monero, in: .usd)
        let hasPending = wallet.activeBalance.all != wallet.activeBalance.unlocked

        return ZStack {
            Color.dsBackground.ignoresSafeArea()

            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 0) {
                    // 1. Header row
                    headerRow(wallet)
                        .padding(.bottom, 18)

                    // 2. Account pill
                    accountPill(wallet)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.bottom, wallet.pendingSeedBackup ? 16 : 24)

                    // 3. Backup banner (optional)
                    if wallet.pendingSeedBackup {
                        backupBanner()
                            .padding(.bottom, 24)
                    }

                    // 4. Balance card
                    balanceCard(wallet, xmrPrice: xmrPrice, hasPending: hasPending)
                        .padding(.bottom, 8)

                    // 5. Exchange rate caption
                    if xmrPrice > 0 {
                        Text("1 XMR = \(String(format: "$%.2f", xmrPrice))")
                            .font(.dsCaption)
                            .foregroundStyle(Color.dsTextTertiary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.bottom, 16)
                    } else {
                        Spacer().frame(height: 16)
                    }

                    // 6. Quick actions
                    quickActionsRow()
                        .padding(.bottom, wallet.pendingSeedBackup ? 12 : 16)

                    // 7. Sync status card
                    syncCard(wallet)
                        .padding(.bottom, 34)

                    // 8. Transactions header (divider + label)
                    VStack(spacing: 0) {
                        Rectangle()
                            .fill(Color.dsBorder)
                            .frame(height: 1)
                        HStack {
                            Text("Transactions")
                                .font(.dsHeadingMD)
                                .foregroundStyle(Color.dsTextPrimary)
                            Spacer()
                        }
                        .padding(.top, 20)
                    }
                    .padding(.bottom, 12)

                    // 9. Transaction list or empty state
                    transactionSection(wallet, xmrPrice: xmrPrice)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
            }
        }
    }

    // MARK: - Header row

    @ViewBuilder
    private func headerRow(_ wallet: XMRWallet) -> some View {
        HStack {
            // Wallet switcher button
            Button {
                showingWalletSheet = true
            } label: {
                HStack(spacing: 10) {
                    // Avatar tile
                    ZStack {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.dsAccent)
                        Text(String(wallet.title.prefix(1)).uppercased())
                            .font(.dsBodyMD)
                            .foregroundStyle(Color.white)
                    }
                    .frame(width: 36, height: 36)

                    // Labels
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Wallet")
                            .font(.dsCaption)
                            .foregroundStyle(Color.dsTextTertiary)
                        Text(wallet.title)
                            .font(.dsBodyMD)
                            .foregroundStyle(Color.dsTextPrimary)
                    }

                    Image(systemName: "chevron.right")
                        .font(.dsCaption)
                        .foregroundStyle(Color.dsTextTertiary)
                }
            }
            .buttonStyle(.plain)

            Spacer()

            // Settings gear button
            Button {
                showingSettingsSheet = true
            } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(Color.dsTextPrimary)
                    .frame(width: 36, height: 36)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.dsBorder, lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Account pill

    @ViewBuilder
    private func accountPill(_ wallet: XMRWallet) -> some View {
        let label = wallet.accountLabel(for: wallet.activeAccountIndex)
        let initial = String(label.prefix(1)).uppercased()

        Button {
            showingAccountSheet = true
        } label: {
            HStack(spacing: 8) {
                // Mini avatar
                ZStack {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.dsJadeSoft)
                    Text(initial)
                        .font(.dsBodySM)
                        .foregroundStyle(Color.dsAccentStrong)
                }
                .frame(width: 20, height: 20)

                Text(label)
                    .font(.dsLabelMD)
                    .foregroundStyle(Color.dsAccentStrong)

                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.dsAccentStrong)
            }
            .padding(.vertical, 5)
            .padding(.leading, 5)
            .padding(.trailing, 13)
            .overlay(
                Capsule()
                    .stroke(Color.dsJadeSoft, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Backup banner

    @ViewBuilder
    private func backupBanner() -> some View {
        HStack(spacing: 12) {
            Image(systemName: "lock.fill")
                .font(.system(size: 18))
                .foregroundStyle(Color.dsDanger)

            VStack(alignment: .leading, spacing: 2) {
                Text("Backup required")
                    .font(.dsBodyMD)
                    .foregroundStyle(Color.dsTextPrimary)
                Text("Save your recovery phrase to secure this wallet")
                    .font(.dsCaption)
                    .foregroundStyle(Color.dsTextSecondary)
            }

            Spacer()

            Button {
                showingBackupAlert = true
            } label: {
                Text("Back up now")
                    .font(.dsCaption)
                    .foregroundStyle(Color.dsDanger)
                    .padding(.vertical, 6)
                    .padding(.horizontal, 12)
                    .overlay(
                        Capsule()
                            .stroke(Color.dsDanger, lineWidth: 1.5)
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(Color.dsDangerSoft)
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    // MARK: - Balance card

    @ViewBuilder
    private func balanceCard(_ wallet: XMRWallet, xmrPrice: Double, hasPending: Bool) -> some View {
        let unlockedPiconero = wallet.activeBalance.unlocked
        let allPiconero = wallet.activeBalance.all
        let lockedPiconero = allPiconero > unlockedPiconero ? allPiconero - unlockedPiconero : 0

        let displayXMR = Double(hasPending ? unlockedPiconero : allPiconero) / 1_000_000_000_000
        let displayUSD = displayXMR * xmrPrice

        ZStack(alignment: .topLeading) {
            // Gradient background
            LinearGradient(
                colors: [Color.green600, Color.green700],
                startPoint: UnitPoint(x: 0.15, y: 0),
                endPoint: UnitPoint(x: 0.85, y: 1)
            )

            // Decorative circles
            GeometryReader { geo in
                // Large soft filled circle (top-right, overflows by 30px)
                Circle()
                    .fill(Color.white.opacity(0.06))
                    .frame(width: 130, height: 130)
                    .position(x: geo.size.width - 35, y: 35)

                // Dashed circle (60px inset from right/top)
                Circle()
                    .stroke(Color.white.opacity(0.14), style: StrokeStyle(lineWidth: 1.5, dash: [4, 4]))
                    .frame(width: 70, height: 70)
                    .position(x: geo.size.width - 95, y: 95)
            }

            // Card content
            VStack(alignment: .leading, spacing: 0) {
                // Label row + eye toggle
                HStack {
                    Text(hasPending ? "Available now" : "Total balance")
                        .font(.dsLabelMD)
                        .foregroundStyle(Color.white.opacity(0.75))

                    Spacer()

                    Button {
                        balanceVisible.toggle()
                    } label: {
                        Image(systemName: balanceVisible ? "eye" : "eye.slash")
                            .font(.dsBodySM)
                            .foregroundStyle(Color.white)
                            .frame(width: 28, height: 28)
                            .background(Color.white.opacity(0.14))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                }

                // Main balance figure
                HStack(alignment: .lastTextBaseline, spacing: 8) {
                    Text(balanceVisible ? displayXMR.xmrFormattedBalance : "••••")
                        .font(.system(size: 34, weight: .bold).monospacedDigit())
                        .foregroundStyle(Color.white)
                    Text("XMR")
                        .font(.dsBodyLG)
                        .foregroundStyle(Color.white.opacity(0.8))
                }
                .padding(.top, 8)

                // USD equivalent
                Text(balanceVisible ? "≈ \(String(format: "$%.2f", displayUSD)) USD" : "≈ •••• USD")
                    .font(.dsBodyMD)
                    .foregroundStyle(Color.white.opacity(0.85))
                    .padding(.top, 4)

                // Pending split row (only shown when funds are locked)
                if hasPending {
                    Divider()
                        .background(Color.white.opacity(0.14))
                        .padding(.top, 16)

                    HStack(alignment: .center) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Total balance")
                                .font(.dsLabelMD)
                                .foregroundStyle(Color.white.opacity(0.75))
                            Text(balanceVisible
                                 ? "\((Double(allPiconero) / 1_000_000_000_000).xmrFormattedBalance) XMR"
                                 : "••••")
                                .font(.dsButtonLG.monospacedDigit())
                                .foregroundStyle(Color.white)
                        }

                        Spacer()

                        VStack(alignment: .trailing, spacing: 2) {
                            HStack(spacing: 4) {
                                Image(systemName: "lock.fill")
                                    .font(.system(size: 10))
                                    .foregroundStyle(Color(red: 0.941, green: 0.776, blue: 0.490)) // #F0C67D
                                Text("Locked")
                                    .font(.dsCaption)
                                    .foregroundStyle(Color.white.opacity(0.75))
                            }
                            Text(balanceVisible
                                 ? "\((Double(lockedPiconero) / 1_000_000_000_000).xmrFormattedBalance) XMR"
                                 : "••••")
                                .font(.dsBodySM.monospacedDigit())
                                .foregroundStyle(Color(red: 0.941, green: 0.776, blue: 0.490))
                        }
                    }
                    .padding(.top, 14)
                }
            }
            .padding(.horizontal, 22)
            .padding(.top, 22)
            .padding(.bottom, 24)
        }
        .clipShape(RoundedRectangle(cornerRadius: 28))
    }

    // MARK: - Quick actions

    @ViewBuilder
    private func quickActionsRow() -> some View {
        HStack(spacing: 10) {
            quickActionCell(label: "Send", icon: "arrow.up.right") {
                showingSendXMR = true
            }
            quickActionCell(label: "Receive", icon: "arrow.down.left") {
                showingReceiveXMR = true
            }
        }
    }

    @ViewBuilder
    private func quickActionCell(label: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                ZStack {
                    Circle()
                        .fill(Color.dsJadeSoft)
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color.dsAccentStrong)
                }
                .frame(width: 44, height: 44)

                Text(label)
                    .font(.dsCaption)
                    .foregroundStyle(Color.dsTextPrimary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Color.dsSurfaceRaised)
            .clipShape(RoundedRectangle(cornerRadius: 18))
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .stroke(Color.dsBorder, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Sync card

    @ViewBuilder
    private func syncCard(_ wallet: XMRWallet) -> some View {
        // walletError takes priority (initialization failure)
        if let error = wallet.walletError {
            syncCardContent(
                icon: "exclamationmark.triangle.fill",
                label: "Wallet error",
                detail: error,
                fg: Color.syncConnecting,
                bg: Color.syncConnectingSoft,
                action: { wallet.restartSync() }
            )
        } else {
            switch wallet.walletState {
            case .connecting:
                syncCardContent(
                    icon: "cable.connector",
                    label: "Connecting",
                    detail: nil,
                    fg: Color.syncConnecting,
                    bg: Color.syncConnectingSoft
                )
            case .syncing(let progress, let remaining):
                let blockSuffix = remaining > 0 ? " · \(remaining) blocks remaining" : ""
                syncCardContent(
                    icon: "clock",
                    label: "Syncing",
                    detail: "\(progress)% synced\(blockSuffix)",
                    fg: Color.syncSyncing,
                    bg: Color.syncSyncingSoft
                )
            case .synced:
                syncCardContent(
                    icon: "checkmark.circle.fill",
                    label: "Synced",
                    detail: wallet.walletHeight > 0 ? "Last block \(wallet.walletHeight)" : nil,
                    fg: Color.dsAccentStrong,
                    bg: Color.dsJadeSoft
                )
            case .notSynced(let error):
                let detail = error == .notStarted ? nil : error.description
                syncCardContent(
                    icon: "shield.fill",
                    label: "Not synced",
                    detail: detail,
                    fg: Color.dsDanger,
                    bg: Color.dsDangerSoft,
                    action: { wallet.restartSync() }
                )
            case .idle:
                syncCardContent(
                    icon: "shield.fill",
                    label: "Idle",
                    detail: nil,
                    fg: Color.dsTextSecondary,
                    bg: Color.syncIdleSoft
                )
            }
        }
    }

    @ViewBuilder
    private func syncCardContent(icon: String, label: String, detail: String?, fg: Color, bg: Color, action: (() -> Void)? = nil) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundStyle(fg)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.dsBodyMD)
                    .foregroundStyle(Color.dsTextPrimary)
                if let detail {
                    Text(detail)
                        .font(.dsCaption)
                        .foregroundStyle(Color.dsTextSecondary)
                }
            }

            Spacer()

            if let action {
                Button(action: action) {
                    Text("Restart")
                        .font(.dsCaption)
                        .foregroundStyle(fg)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(fg.opacity(0.15))
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(bg)
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    // MARK: - Transaction section

    @ViewBuilder
    private func transactionSection(_ wallet: XMRWallet, xmrPrice: Double) -> some View {
        let allTx = wallet.transactions
        let accountTx = allTx.filter { $0.account == Int(wallet.activeAccountIndex) }

        if accountTx.isEmpty {
            // Empty state
            VStack(spacing: 8) {
                Image(systemName: "qrcode")
                    .font(.system(size: 40))
                    .foregroundStyle(Color.dsTextTertiary)
                Text("No transactions yet")
                    .font(.dsBodyMD)
                    .foregroundStyle(Color.dsTextTertiary)
                Text("Receive Monero to get started")
                    .font(.dsBodySM)
                    .foregroundStyle(Color.dsTextTertiary.opacity(0.85))
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 60)
        } else {
            // Transaction list card
            VStack(spacing: 0) {
                ForEach(Array(accountTx.enumerated()), id: \.element.hash) { idx, tx in
                    VStack(spacing: 0) {
                        Button { selectedTransaction = tx } label: {
                            transactionRow(tx, xmrPrice: xmrPrice)
                        }
                        .buttonStyle(.plain)

                        if idx < accountTx.count - 1 {
                            Divider()
                                .padding(.leading, 66)
                        }
                    }
                }
            }
            .background(Color.dsSurfaceRaised)
            .clipShape(RoundedRectangle(cornerRadius: 22))
            .overlay(
                RoundedRectangle(cornerRadius: 22)
                    .stroke(Color.dsBorder, lineWidth: 1)
            )
        }
    }

    @ViewBuilder
    private func transactionRow(_ tx: TransactionInfo, xmrPrice: Double) -> some View {
        if !balanceVisible {
            // Skeleton / privacy mode
            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.dsSurface2)
                    .frame(width: 38, height: 38)

                VStack(alignment: .leading, spacing: 6) {
                    RoundedRectangle(cornerRadius: 5)
                        .fill(Color.dsSurface2)
                        .frame(width: 90, height: 10)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.dsSurface2)
                        .frame(width: 60, height: 8)
                }

                Spacer()

                RoundedRectangle(cornerRadius: 5)
                    .fill(Color.dsSurface2)
                    .frame(width: 56, height: 10)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .contentShape(Rectangle())
        } else {
            let isIn = tx.type == .incoming
            let xmrAmount = Double(abs(tx.amount)) / 1_000_000_000_000
            let usdAmount = xmrAmount * xmrPrice
            let sign = isIn ? "+" : "−"
            let dateLabel = txDateLabel(tx.timestamp)

            HStack(spacing: 12) {
                // Icon tile
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(tx.isFailed ? Color.dsTextTertiary.opacity(0.12) : isIn ? Color.dsJadeSoft : Color.dsDanger.opacity(0.12))
                    Image(systemName: isIn ? "arrow.down.left" : "arrow.up.right")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(tx.isFailed ? Color.dsTextTertiary : isIn ? Color.dsAccentStrong : Color.dsDanger)
                }
                .frame(width: 38, height: 38)

                // Left text
                VStack(alignment: .leading, spacing: 2) {
                    Text((isIn ? "Received" : "Sent") + (tx.isFailed ? " (Failed)" : tx.isPending ? " (Pending)" : ""))
                        .font(.dsBodyMD)
                        .foregroundStyle(Color.dsTextPrimary)
                    Text(dateLabel)
                        .font(.dsCaption)
                        .foregroundStyle(Color.dsTextTertiary)
                }

                Spacer()

                // Right amount
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(sign)\(xmrAmount.xmrFormattedBalance)")
                        .font(.dsBodyMD.monospacedDigit())
                        .foregroundStyle(isIn ? Color.dsAccentStrong : Color.dsTextPrimary)
                    if xmrPrice > 0 {
                        Text(String(format: "$%.2f", usdAmount))
                            .font(.dsCaption)
                            .foregroundStyle(Color.dsTextTertiary)
                    }
                }

                Image(systemName: "chevron.right")
                    .font(.dsCaption)
                    .foregroundStyle(Color.dsTextTertiary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .contentShape(Rectangle())
        }
    }

    // MARK: - Helpers

    private func txDateLabel(_ timestamp: Int) -> String {
        let date = Date(timeIntervalSince1970: TimeInterval(timestamp))
        let time = timeFormatter.string(from: date)
        if Calendar.current.isDateInToday(date) {
            return "Today · \(time)"
        } else if Calendar.current.isDateInYesterday(date) {
            return "Yesterday · \(time)"
        } else {
            return shortDateFormatter.string(from: date) + " · " + time
        }
    }

    // MARK: - Mac view (preserved for reference)

    var macView: some View {
        HStack(spacing: 0) {
            VStack {
                HStack {
                    Spacer()
                    Text("New Wallet")
                        .onTapGesture { showingTitleAlert = true }
                        .alert("Enter Wallet Title", isPresented: $showingTitleAlert) {
                            TextField("Wallet Title", text: $titleInput)
                            Button("OK") {}
                                .disabled(titleInput.isEmpty)
                            Button("Cancel") {}
                        }
                    Spacer()
                }
                Divider()
                List {
                    ForEach(walletManager.wallets) { wallet in
                        Text(wallet.title)
                    }
                }
                Spacer()
            }
            .background(.white)
            .frame(minWidth: 100, maxWidth: 100, minHeight: 0, maxHeight: .infinity, alignment: .topLeading)

            HStack {
                Spacer()
                VStack {
                    Spacer()
                    Text("Wallet Details here")
                    Spacer()
                }
                Spacer()
            }
        }
    }
}

// MARK: - Onboarding

private struct OnboardingView: View {
    let onCreateWallet: () -> Void
    let onImportWallet: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    // Decoration circles: left (green600) → right, leftmost on top
    // Dark ramp: green-600 → #2E3324 per design handoff
    private var decorationColors: [Color] {
        colorScheme == .dark
        ? [
            .green600,
            Color(red: 89/255, green: 100/255, blue: 42/255),   // #59642A
            Color(red: 69/255, green: 78/255, blue: 40/255),    // #454E28
            Color(red: 56/255, green: 63/255, blue: 38/255),    // #383F26
            Color(red: 46/255, green: 51/255, blue: 36/255)     // #2E3324
          ]
        : [
            .green600,
            Color(red: 138/255, green: 154/255, blue: 107/255), // #8A9A6B
            Color(red: 174/255, green: 181/255, blue: 150/255), // #AEB596
            Color(red: 199/255, green: 202/255, blue: 180/255), // #C7CAB4
            .green200
          ]
    }

    var body: some View {
        ZStack {
            Color.dsBackground.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                // Decoration zone: 5 circles (88pt each, 52pt step), right-aligned
                Spacer()
                HStack {
                    ZStack(alignment: .leading) {
                        // Draw rightmost first so leftmost (green600) renders on top
                        ForEach((0..<5).reversed(), id: \.self) { i in
                            Circle()
                                .fill(decorationColors[i])
                                .frame(width: 88, height: 88)
                                .offset(x: CGFloat(i) * 52)
                        }
                    }
                    .frame(width: 296, height: 88)
                }
                .padding(.top, 4)
                .padding(.bottom, 32)
                
                Spacer()

                Text("Private money,")
                    .font(.dsDisplayLG)
                    .foregroundColor(.dsTextPrimary)
                    .kerning(-0.3)

                Text("made simple.")
                    .font(.dsDisplayLG)
                    .foregroundColor(.dsAccentStrong)
                    .kerning(-0.3)
                    .padding(.top, 2)

                Text("A non-custodial Monero wallet built for people who'd rather not explain themselves.")
                    .font(.dsBodyLG)
                    .foregroundColor(.dsTextSecondary)
                    .lineSpacing(4)
                    .frame(maxWidth: 320, alignment: .leading)
                    .padding(.top, 16)

                Spacer()

                VStack(spacing: 12) {
                    Button("Create a new wallet", action: onCreateWallet)
                        .buttonStyle(.dsPrimary)

                    Button("I have a seed phrase", action: onImportWallet)
                        .buttonStyle(.dsSecondary)

                    Text("No sign-ups. No KYC. Your keys, your XMR.")
                        .font(.dsCaption)
                        .foregroundColor(.dsTextTertiary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, 14)
                }
                .padding(.bottom, 20)
            }
            .padding(.horizontal, 24)
        }
    }
}

// MARK: - TransactionType description

extension TransactionType {
    var description: String {
        switch self {
        case .incoming: return "Incoming"
        case .outgoing: return "Outgoing"
        }
    }
}
