//
//  WalletSwitchSheet.swift
//  CapsizedVault
//
//  Bottom sheet: switch between wallets, add a new wallet, or restore one.
//  Balance is shown only for the active wallet (inactive wallets don't sync).
//

import SwiftUI
import CapsizedMoneroKit

struct WalletSwitchSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var walletManager: WalletManager
    let xmrPrice: Double
    let balanceVisible: Bool
    let onAddWallet: () -> Void
    let onRestoreWallet: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Your wallets")
                .font(.system(size: 19, weight: .bold))
                .foregroundStyle(Color.dsTextPrimary)
                .padding(.bottom, 12)

            // Wallet list card
            let wallets = walletManager.wallets
            let activeId = walletManager.activeWallet?.walletId
            ScrollViewReader { proxy in
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 0) {
                        ForEach(Array(wallets.enumerated()), id: \.element.walletId) { idx, wallet in
                            walletRow(wallet: wallet, isLast: idx == wallets.count - 1)
                                .id(wallet.walletId)
                        }
                    }
                }
                .onAppear {
                    if let id = activeId {
                        proxy.scrollTo(id, anchor: .center)
                    }
                }
            }
            .background(Color.dsSurfaceRaised)
            .clipShape(RoundedRectangle(cornerRadius: 22))
            .overlay(
                RoundedRectangle(cornerRadius: 22)
                    .stroke(Color.dsBorder, lineWidth: 1)
            )

            // Action buttons
            HStack(spacing: 10) {
                Button {
                    onAddWallet()
                    dismiss()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "plus")
                            .font(.system(size: 13, weight: .semibold))
                        Text("Add new wallet")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .foregroundStyle(Color.dsTextPrimary)
                    .overlay(
                        RoundedRectangle(cornerRadius: 999)
                            .stroke(Color.dsBorder, lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)

                Button {
                    onRestoreWallet()
                    dismiss()
                } label: {
                    Text("Restore wallet")
                        .font(.system(size: 14, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .foregroundStyle(Color.dsTextPrimary)
                        .overlay(
                            RoundedRectangle(cornerRadius: 999)
                                .stroke(Color.dsBorder, lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
            }
            .padding(.top, 16)
        }
        .padding(.horizontal, 20)
        .padding(.top, 24)
        .padding(.bottom, 28)
        .background(Color.dsSurface.ignoresSafeArea())
    }

    @ViewBuilder
    private func walletRow(wallet: XMRWallet, isLast: Bool) -> some View {
        let isActive = wallet.walletId == walletManager.activeWallet?.walletId
        let initial = String(wallet.title.prefix(1)).uppercased()

        // Use the cached balance (persisted to Realm after each sync update).
        // -1 means the wallet has never synced; show "–" in that case.
        let cached = wallet.cachedTotalUnlocked
        let hasBalance = cached >= 0
        let xmrTotal = hasBalance ? Double(cached) / 1_000_000_000_000 : 0

        VStack(spacing: 0) {
            Button {
                walletManager.setActiveWallet(wallet)
                dismiss()
            } label: {
                HStack(spacing: 12) {
                    // Avatar tile
                    ZStack {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(isActive ? Color.dsAccent : Color.dsSurface2)
                        Text(initial)
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(isActive ? Color.white : Color.dsTextSecondary)
                    }
                    .frame(width: 36, height: 36)

                    // Name + balance
                    VStack(alignment: .leading, spacing: 2) {
                        Text(wallet.title)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Color.dsTextPrimary)
                        if hasBalance && balanceVisible {
                            Text("\(xmrTotal.xmrFormattedBalance) XMR · ≈ $\(String(format: "%.2f", xmrTotal * xmrPrice))")
                                .font(.system(size: 13))
                                .foregroundStyle(Color.dsTextTertiary)
                        } else if hasBalance {
                            Text("•••• XMR · ≈ $••••")
                                .font(.system(size: 13))
                                .foregroundStyle(Color.dsTextTertiary)
                        } else {
                            Text("–")
                                .font(.system(size: 13))
                                .foregroundStyle(Color.dsTextTertiary)
                        }
                    }

                    Spacer()

                    if isActive {
                        Image(systemName: "checkmark")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Color.dsAccentStrong)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if !isLast {
                Divider()
                    .padding(.leading, 64)
            }
        }
    }
}
