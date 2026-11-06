//
//  ZcashBalancePoolsView.swift
//  CapsizedVault
//

import SwiftUI

struct ZcashBalancePoolsView: View {

    @ObservedObject var wallet: ZECWallet
    let price: Double
    let balanceVisible: Bool

    // MARK: - Derived values

    /// Re-derived on every render from `wallet.accounts`/`wallet.activeAccountIndex` (both
    /// `@Published`) rather than captured once, so the breakdown stays live while syncing —
    /// same reasoning as `ZcashTransactionDetailsView.liveTransaction`.
    private var account: WalletAccountBalance {
        wallet.accounts.first(where: { $0.index == Int(wallet.activeAccountIndex) })
            ?? WalletAccountBalance(
                index: Int(wallet.activeAccountIndex),
                label: "",
                total: .zero(.zcash),
                spendable: .zero(.zcash),
                pending: .zero(.zcash),
                transparent: nil
            )
    }

    private var ticker: String { Coin.zcash.ticker }

    private func amountText(_ amount: CoinAmount?) -> String {
        guard balanceVisible else { return "••••" }
        return "\((amount ?? .zero(.zcash)).formatted(style: .balance)) \(ticker)"
    }

    private var totalUSDText: String {
        guard balanceVisible else { return "≈ •••• USD" }
        return "≈ \(String(format: "$%.2f", account.total.fiat(price: price))) USD"
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            // Fixed header
            Text("Balance Across Pools")
                .font(.system(size: 19, weight: .bold))
                .foregroundStyle(Color.dsTextPrimary)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.bottom, 20)

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {

                    // 1. Total summary card
                    summaryCard

                    // 2. Pools section
                    sectionLabel("Pools")
                        .padding(.top, 28)
                    poolsCard
                        .padding(.top, 10)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 28)
            }
        }
        .padding(.top, 20)
        .background(Color.dsSurface.ignoresSafeArea())
    }

    // MARK: - Summary card

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Total balance")
                .font(.system(size: 13))
                .foregroundStyle(Color.dsTextTertiary)
            Text(amountText(account.total))
                .font(.system(size: 24, weight: .bold).monospacedDigit())
                .foregroundStyle(Color.dsTextPrimary)
            Text(totalUSDText)
                .font(.system(size: 13))
                .foregroundStyle(Color.dsTextTertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(Color.dsSurfaceRaised)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(Color.dsBorder, lineWidth: 1)
        )
    }

    // MARK: - Pools card

    private var poolsCard: some View {
        VStack(spacing: 0) {
            detailRow(label: "Transparent", value: amountText(account.transparent), isLast: false)
            detailRow(label: "Sapling", value: amountText(account.sapling), isLast: false)
            detailRow(label: "Orchard", value: amountText(account.orchard), isLast: false)
            detailRow(label: "Ironwood", value: amountText(account.ironwood), isLast: true)
        }
        .background(Color.dsSurfaceRaised)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(Color.dsBorder, lineWidth: 1)
        )
    }

    private func detailRow(label: String, value: String, isLast: Bool) -> some View {
        VStack(spacing: 0) {
            HStack {
                Text(label)
                    .font(.system(size: 14))
                    .foregroundStyle(Color.dsTextTertiary)
                Spacer()
                Text(value)
                    .font(.system(size: 15, weight: .semibold).monospacedDigit())
                    .foregroundStyle(Color.dsTextPrimary)
                    .multilineTextAlignment(.trailing)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)

            if !isLast {
                Divider()
                    .padding(.leading, 16)
            }
        }
    }

    // MARK: - Section label

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 13, weight: .bold))
            .foregroundStyle(Color.dsTextTertiary)
            .kerning(0.3)
    }
}
