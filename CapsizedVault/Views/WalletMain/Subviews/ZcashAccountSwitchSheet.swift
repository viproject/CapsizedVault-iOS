//
//  ZcashAccountSwitchSheet.swift
//  CapsizedVault
//
//  Bottom sheet: switch between accounts within the current Zcash wallet, derive a new
//  account (seed wallets), or add/remove an imported viewing key (view-only wallets).
//  Sibling of AccountSwitchSheet, which stays Monero-only — the two coins' account models
//  (ZIP-32 derivation vs. imported viewing keys, possible index gaps) diverge enough that
//  sharing one view would mean branching almost every row on the coin anyway.
//

import SwiftUI

struct ZcashAccountSwitchSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var wallet: ZECWallet
    let price: Double
    let balanceVisible: Bool

    @State private var showingAddAccount = false
    @State private var renamingAccountIndex: Int? = nil
    @State private var removingAccountIndex: Int? = nil
    @State private var isBusy = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Switch account")
                .font(.dsHeadingMD)
                .foregroundStyle(Color.dsTextPrimary)
                .padding(.horizontal, 20)
                .padding(.top, 24)
                .padding(.bottom, 12)

            ScrollViewReader { proxy in
                List {
                    ForEach(wallet.accountList) { info in
                        accountRow(info)
                            .listRowInsets(EdgeInsets())
                            .listRowBackground(Color.dsSurfaceRaised)
                            .listRowSeparator(.hidden)
                            .id(info.index)
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                if wallet.isWatchOnly && wallet.accountList.count > 1 {
                                    Button(role: .destructive) {
                                        removingAccountIndex = info.index
                                    } label: {
                                        Label("Remove", systemImage: "trash")
                                    }
                                }
                                Button {
                                    renamingAccountIndex = info.index
                                } label: {
                                    Label("Rename", systemImage: "pencil")
                                }
                                .tint(Color.dsAccentStrong)
                            }
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .onAppear {
                    proxy.scrollTo(Int(wallet.activeAccountIndex), anchor: .center)
                }
            }
            .background(Color.dsSurfaceRaised)
            .clipShape(RoundedRectangle(cornerRadius: 22))
            .overlay(
                RoundedRectangle(cornerRadius: 22)
                    .stroke(Color.dsBorder, lineWidth: 1)
            )
            .padding(.horizontal, 20)

            Button {
                showingAddAccount = true
            } label: {
                HStack(spacing: 8) {
                    if isBusy {
                        ProgressView()
                    } else {
                        Image(systemName: "plus")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    Text(wallet.capabilities.accountCreation == .importViewingKey ? "Add viewing key" : "Create new account")
                        .font(.dsBodyMD)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .foregroundStyle(Color.dsTextPrimary)
                .overlay(
                    RoundedRectangle(cornerRadius: 999)
                        .stroke(Color.dsBorder, lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            .disabled(isBusy)
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 28)
        }
        .background(Color.dsSurface.ignoresSafeArea())
        .sheet(isPresented: $showingAddAccount) {
            if wallet.capabilities.accountCreation == .importViewingKey {
                AddViewingKeyView { label, ufvk, birthday in
                    runMutation { await wallet.addViewingKey(ufvk, label: label, birthday: birthday) }
                }
                .presentationDetents([.height(460)])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(28)
            } else {
                AddAccountView(footnote: "Zodl/Zashi only show Account 1 when you restore this seed there — accounts created here won't appear.") { label in
                    runMutation { await wallet.deriveAccount(label: label) }
                }
                .presentationDetents([.height(400)])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(28)
            }
        }
        .sheet(item: Binding(
            get: { renamingAccountIndex.map { RenamingTarget(index: $0) } },
            set: { renamingAccountIndex = $0?.index }
        )) { target in
            RenameAccountView(currentLabel: wallet.accountLabel(for: UInt32(target.index))) { newLabel in
                wallet.setAccountLabel(accountIndex: UInt32(target.index), label: newLabel)
            }
            .presentationDetents([.height(340)])
            .presentationDragIndicator(.visible)
            .presentationCornerRadius(28)
        }
        .alert("Remove viewing key?", isPresented: Binding(
            get: { removingAccountIndex != nil },
            set: { if !$0 { removingAccountIndex = nil } }
        )) {
            Button("Cancel", role: .cancel) { removingAccountIndex = nil }
            Button("Remove", role: .destructive) {
                guard let index = removingAccountIndex else { return }
                removingAccountIndex = nil
                runMutation { await wallet.removeViewingKey(accountIndex: index) }
            }
        } message: {
            Text("This removes the account and its transaction history from this wallet. You can re-add it later with the same viewing key.")
        }
        .alert("Couldn't update accounts", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private func runMutation(_ operation: @escaping () async -> Result<Void, WalletError>) {
        isBusy = true
        Task {
            let result = await operation()
            isBusy = false
            if case .failure(let error) = result {
                errorMessage = error.userMessage
            }
        }
    }

    @ViewBuilder
    private func accountRow(_ info: ZcashAccountInfo) -> some View {
        let isSelected = Int(wallet.activeAccountIndex) == info.index
        let initial = String(info.label.prefix(1)).uppercased()
        let balance = wallet.accounts.first(where: { $0.index == info.index })

        VStack(spacing: 0) {
            Button {
                wallet.setActiveAccountIndex(info.index)
                dismiss()
            } label: {
                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(isSelected ? Color.dsAccent : Color.dsSurface2)
                        Text(initial)
                            .font(.dsLabelMDBold)
                            .foregroundStyle(isSelected ? Color.white : Color.dsTextSecondary)
                    }
                    .frame(width: 36, height: 36)

                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text(info.label)
                                .font(.dsLabelMD)
                                .foregroundStyle(Color.dsTextPrimary)
                            if info.isAddedViewingKey {
                                Text("Added key")
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundStyle(Color.dsAccentStrong)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.dsJadeSoft)
                                    .clipShape(Capsule())
                            }
                        }
                        if let balance {
                            if balanceVisible {
                                Text("\(balance.total.formatted(style: .balance)) ZEC · ≈ $\(String(format: "%.2f", balance.total.fiat(price: price)))")
                                    .font(.dsBodySM)
                                    .foregroundStyle(Color.dsTextTertiary)
                            } else {
                                Text("•••• ZEC · ≈ $••••")
                                    .font(.dsBodySM)
                                    .foregroundStyle(Color.dsTextTertiary)
                            }
                        }
                    }

                    Spacer()

                    if isSelected {
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

            if info.index != wallet.accountList.last?.index {
                Divider()
                    .padding(.leading, 64)
            }
        }
    }
}

// MARK: - Rename sheet target (Identifiable wrapper for sheet(item:))

private struct RenamingTarget: Identifiable {
    let index: Int
    var id: Int { index }
}
