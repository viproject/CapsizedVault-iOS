//
//  ZcashTransactionDetailsView.swift
//  CapsizedVault
//

import SwiftUI

struct ZcashTransactionDetailsView: View {

    let transaction: WalletTransaction
    @ObservedObject var wallet: ZECWallet

    @State private var detail: ZcashTransactionDetail?
    @State private var copiedField: String? = nil

    // MARK: - Derived values

    /// Always reflects the latest data from `ZECWallet` (confirmations, pending state, etc.) —
    /// `wallet.transactions`/`wallet.chainHeight` are both `@Published`, so re-reading through
    /// this on every render keeps the view live while the wallet keeps syncing, same as
    /// `TransactionDetailsView.liveTransaction` does for Monero.
    private var liveTransaction: WalletTransaction {
        wallet.transactions.first(where: { $0.hash == transaction.hash }) ?? transaction
    }

    private var isIn: Bool { liveTransaction.type == .incoming }

    private var txDate: Date {
        Date(timeIntervalSince1970: TimeInterval(liveTransaction.timestamp))
    }

    private var relativeTime: String {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .full
        return f.localizedString(for: txDate, relativeTo: Date())
    }

    private var fullDate: String {
        let f = DateFormatter()
        f.dateFormat = "d MMM yyyy 'at' h:mma"
        f.amSymbol = "am"
        f.pmSymbol = "pm"
        return f.string(from: txDate)
    }

    private var amountString: String {
        let prefix = isIn ? "+" : "-"
        return "\(prefix)\(liveTransaction.amount.formatted()) \(Coin.zcash.ticker)"
    }

    private var feeString: String {
        "\(liveTransaction.fee.formatted()) \(Coin.zcash.ticker)"
    }

    private var isPending: Bool { liveTransaction.isPending }
    private var isFailed: Bool { liveTransaction.isFailed }

    private var confirmationsText: String {
        if isPending { return "0" }
        let chainHeight = wallet.chainHeight
        guard chainHeight > 0, liveTransaction.blockHeight > 0 else { return "-" }
        let conf = chainHeight > liveTransaction.blockHeight
            ? chainHeight - liveTransaction.blockHeight + 1 : 1
        return "\(conf)"
    }

    private var statusText: String? {
        if isPending { return "Pending" }
        if isFailed { return "Failed" }
        return nil
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            // Fixed header
            Text("Transaction")
                .font(.system(size: 19, weight: .bold))
                .foregroundStyle(Color.dsTextPrimary)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.bottom, 20)

            // Scrollable content
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {

                    // 1. Summary card
                    summaryCard

                    // 2. Details section
                    sectionLabel("Details")
                        .padding(.top, 28)
                    detailsCard
                        .padding(.top, 10)

                    // 3. Transaction ID
                    sectionLabel("Transaction ID")
                        .padding(.top, 24)
                    copyBlock(text: transaction.hash, field: "txid", mono: true)
                        .padding(.top, 10)

                    // 4. Memo (optional)
                    if let memo = detail?.memo, !memo.isEmpty {
                        sectionLabel("Memo")
                            .padding(.top, 24)
                        copyBlock(text: memo, field: "memo", mono: false)
                            .padding(.top, 10)
                    }

                    // 5. Address (optional)
                    if let address = detail?.recipient, !address.isEmpty {
                        sectionLabel("Address")
                            .padding(.top, 24)
                        copyBlock(text: address, field: "address", mono: true)
                            .padding(.top, 10)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 28)
            }
        }
        .padding(.top, 20)
        .background(Color.dsSurface.ignoresSafeArea())
        .task {
            detail = try? await wallet.transactionDetail(forHash: transaction.hash)
        }
    }

    // MARK: - Summary card

    private var summaryCard: some View {
        HStack(spacing: 12) {
            // Direction badge
            ZStack {
                Circle()
                    .fill(isIn
                          ? Color.dsJadeSoft
                          : Color.dsDanger.opacity(0.12))
                Image(systemName: isIn ? "arrow.down.left" : "arrow.up.right")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(isIn ? Color.dsAccentStrong : Color.dsDanger)
            }
            .frame(width: 44, height: 44)

            // Label + relative time
            VStack(alignment: .leading, spacing: 2) {
                Text((liveTransaction.isShielding ? "Shielding" : isIn ? "Received" : "Sent") + (isFailed ? " (Failed)" : isPending ? " (Pending)" : ""))
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(Color.dsTextPrimary)
                Text(relativeTime)
                    .font(.system(size: 13))
                    .foregroundStyle(Color.dsTextTertiary)
            }

            Spacer()

            // Amount
            Text(amountString)
                .font(.system(size: 18, weight: .bold).monospacedDigit())
                .foregroundStyle(Color.dsTextPrimary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(Color.dsSurfaceRaised)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(Color.dsBorder, lineWidth: 1)
        )
    }

    // MARK: - Details card

    private var detailsCard: some View {
        let hasStatus = statusText != nil
        return VStack(spacing: 0) {
            detailRow(label: "Date",          value: fullDate,           isLast: false)
            detailRow(label: "Fee",           value: feeString,          isLast: false)
            detailRow(label: "Confirmations", value: confirmationsText,  isLast: !hasStatus)
            if let status = statusText {
                detailRow(label: "Status", value: status, isLast: !isFailed)
            }
            if isFailed {
                detailRow(label: "Reason", value: "Transaction expired before it was mined", isLast: true)
            }
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

    // MARK: - Copy block

    private func copyBlock(text: String, field: String, mono: Bool) -> some View {
        let isCopied = copiedField == field
        return Button {
            UIPasteboard.general.string = text
            copiedField = field
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                if copiedField == field { copiedField = nil }
            }
        } label: {
            ZStack(alignment: .topTrailing) {
                // Value text with right padding to clear the copy affordance
                Text(text)
                    .font(mono
                          ? .system(size: 13, design: .monospaced)
                          : .system(size: 15))
                    .foregroundStyle(Color.dsTextPrimary)
                    .lineSpacing(3)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.trailing, 64)

                // Copy / Copied affordance
                HStack(spacing: 4) {
                    Image(systemName: isCopied ? "checkmark" : "doc.on.doc")
                        .font(.system(size: 11))
                    Text(isCopied ? "Copied" : "Copy")
                        .font(.system(size: 12, weight: .semibold))
                }
                .foregroundStyle(Color.dsAccentStrong)
                .animation(.easeInOut(duration: 0.15), value: isCopied)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.dsSurfaceRaised)
            .clipShape(RoundedRectangle(cornerRadius: 18))
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .stroke(Color.dsBorder, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}
