//
//  AccountSwitchSheet.swift
//  CapsizedVault
//
//  Bottom sheet: switch between accounts within the current wallet,
//  or launch the Create New Account flow.
//

import SwiftUI
import CapsizedMoneroKit

struct AccountSwitchSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var wallet: XMRWallet
    let xmrPrice: Double
    let balanceVisible: Bool

    @State private var showingCreateAccount = false
    @State private var renamingAccountIndex: Int? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Switch account")
                .font(.dsHeadingMD)
                .foregroundStyle(Color.dsTextPrimary)
                .padding(.horizontal, 20)
                .padding(.top, 24)
                .padding(.bottom, 12)

            // Account list card
            let count = wallet.numberOfAccounts()
            let activeIndex = Int(wallet.activeAccountIndex)
            ScrollViewReader { proxy in
                List {
                    ForEach(0..<count, id: \.self) { i in
                        accountRow(index: i, isLast: i == count - 1)
                            .listRowInsets(EdgeInsets())
                            .listRowBackground(Color.dsSurfaceRaised)
                            .listRowSeparator(.hidden)
                            .id(i)
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button {
                                    renamingAccountIndex = i
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
                    proxy.scrollTo(activeIndex, anchor: .center)
                }
            }
            .background(Color.dsSurfaceRaised)
            .clipShape(RoundedRectangle(cornerRadius: 22))
            .overlay(
                RoundedRectangle(cornerRadius: 22)
                    .stroke(Color.dsBorder, lineWidth: 1)
            )
            .padding(.horizontal, 20)

            // Create new account button
            Button {
                showingCreateAccount = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "plus")
                        .font(.system(size: 14, weight: .semibold))
                    Text("Create new account")
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
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 28)
        }
        .background(Color.dsSurface.ignoresSafeArea())
        .sheet(isPresented: $showingCreateAccount) {
            AddAccountView { label in
                wallet.addNewAccount(label: label)
            }
            .presentationDetents([.height(340)])
            .presentationDragIndicator(.visible)
            .presentationCornerRadius(28)
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
    }

    @ViewBuilder
    private func accountRow(index: Int, isLast: Bool) -> some View {
        let isSelected = Int(wallet.activeAccountIndex) == index
        let label = wallet.accountLabel(for: UInt32(index))
        let initial = String(label.prefix(1)).uppercased()
        let balance: BalanceInfo = wallet.accountBalances.indices.contains(index)
            ? wallet.accountBalances[index]
            : BalanceInfo(all: 0, unlocked: 0)
        let xmrAmount = Double(balance.unlocked) / 1_000_000_000_000

        VStack(spacing: 0) {
            Button {
                wallet.setActiveAccountIndex(index)
                dismiss()
            } label: {
                HStack(spacing: 12) {
                    // Avatar tile
                    ZStack {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(isSelected ? Color.dsAccent : Color.dsSurface2)
                        Text(initial)
                            .font(.dsLabelMDBold)
                            .foregroundStyle(isSelected ? Color.white : Color.dsTextSecondary)
                    }
                    .frame(width: 36, height: 36)

                    // Name + balance
                    VStack(alignment: .leading, spacing: 2) {
                        Text(label)
                            .font(.dsLabelMD)
                            .foregroundStyle(Color.dsTextPrimary)
                        if balanceVisible {
                            Text("\(xmrAmount.xmrFormattedBalance) XMR · ≈ $\(String(format: "%.2f", xmrAmount * xmrPrice))")
                                .font(.dsBodySM)
                                .foregroundStyle(Color.dsTextTertiary)
                        } else {
                            Text("•••• XMR · ≈ $••••")
                                .font(.dsBodySM)
                                .foregroundStyle(Color.dsTextTertiary)
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

            if !isLast {
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
