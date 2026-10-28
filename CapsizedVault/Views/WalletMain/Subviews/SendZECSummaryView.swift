import SwiftUI

struct SendZECSummaryView: View {

    let receiverAddress: String
    let amount: CoinAmount
    let availableBalance: CoinAmount
    let estimatedFee: CoinAmount
    let zecToUsd: Double
    let memo: String?

    let backAction: () -> Void

    private var total: CoinAmount { amount + estimatedFee }
    private var balanceAfter: CoinAmount { availableBalance - total }

    @StateObject private var walletManager = WalletManager.shared
    @State private var showErrorAlert = false
    @State private var errorMessage = ""
    @State private var isSending = false
    @State private var showAuthChallenge = false
    @State private var buttonResetTick = 0
    @State private var showSuccessSheet = false

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {

                // MARK: - Amount Hero
                VStack(spacing: 4) {
                    HStack(alignment: .lastTextBaseline, spacing: 8) {
                        Text(amount.formatted(style: .full))
                            .font(.system(size: 38, weight: .medium, design: .rounded))
                            .foregroundStyle(Color.dsTextPrimary)
                        Text("ZEC")
                            .font(.title3)
                            .fontWeight(.medium)
                            .foregroundStyle(Color.dsTextSecondary)
                    }
                    Text("≈ \(usd(amount))")
                        .font(.subheadline)
                        .foregroundStyle(Color.dsTextSecondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
                .background(Color.dsSurface2)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Color.dsBorder, lineWidth: 1))
                .padding(.bottom, 20)

                // MARK: - Section label
                sectionLabel("Transaction details")

                // MARK: - Details Card
                VStack(spacing: 0) {
                    summaryRow(label: "To") {
                        Text(receiverAddress)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(Color.dsTextPrimary)
                            .multilineTextAlignment(.trailing)
                            .lineLimit(3)
                    }
                    Divider().padding(.leading, 16)
                    summaryRow(label: "Amount") {
                        amountStack(amount)
                    }
                    Divider().padding(.leading, 16)
                    summaryRow(label: "Fee") {
                        amountStack(estimatedFee)
                    }
                    Divider()
                    summaryRow(label: "Total", bold: true) {
                        amountStack(total)
                    }
                    .background(Color.dsSurface)
                }
                .background(Color.dsSurface2)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Color.dsBorder, lineWidth: 1))
                .padding(.bottom, 12)

                // MARK: - Memo Card
                if let memo, !memo.isEmpty {
                    VStack(spacing: 0) {
                        summaryRow(label: "Memo") {
                            Text(memo)
                                .font(.subheadline)
                                .foregroundStyle(Color.dsTextPrimary)
                                .multilineTextAlignment(.trailing)
                        }
                    }
                    .background(Color.dsSurface2)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Color.dsBorder, lineWidth: 1))
                    .padding(.bottom, 12)
                }

                // MARK: - Available Funds Card
                VStack(spacing: 0) {
                    summaryRow(label: "Available funds") {
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("\(availableBalance.formatted(style: .balance)) ZEC")
                                .font(.subheadline).fontWeight(.medium)
                                .foregroundStyle(Color.dsTextPrimary)
                            Text("after: \(balanceAfter.formatted(style: .balance)) ZEC")
                                .font(.caption)
                                .foregroundStyle(Color.dsTextSecondary)
                        }
                    }
                }
                .background(Color.dsSurface2)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Color.dsBorder, lineWidth: 1))
                .padding(.bottom, 20)

                // MARK: - Warning
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.caption)
                        .foregroundStyle(Color.dsDanger)
                        .padding(.top, 1)
                    Text("Zcash transactions are irreversible. Please verify the recipient address before confirming.")
                        .font(.caption)
                        .foregroundStyle(Color.dsDanger)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(12)
                .background(Color.dsDangerSoft)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Color.dsDanger.opacity(0.25), lineWidth: 1))
                .padding(.bottom, 24)

                // MARK: - Confirm Button
                HoldToSendButton(isSending: isSending, showError: showErrorAlert, resetTrigger: buttonResetTick) {
                    handleSendAction()
                }

                Button {
                    backAction()
                } label: {
                    Text("Back")
                }
                .buttonStyle(.dsSecondary)
                .disabled(isSending)
                .padding(.top, 10)
                .padding(.bottom, 28)
            }
            .padding(.horizontal, 20)
            .padding(.top, 24)
            .instantScrollViewTouches()
            .alert("Error", isPresented: $showErrorAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
        }
        .interactiveDismissDisabled()
        .fullScreenCover(isPresented: $showAuthChallenge) {
            TransactionAuthView(onAuthenticated: {
                showAuthChallenge = false
                confirmTransaction()
            }, onCancel: {
                showAuthChallenge = false
                buttonResetTick += 1
            })
        }
        .sheet(isPresented: $showSuccessSheet) {
            ZECTransactionSuccessSheet(amount: amount, zecToUsd: zecToUsd) {
                dismiss()
            }
            .presentationDetents([.height(420)])
            .presentationDragIndicator(.hidden)
        }
    }

    // MARK: - Confirm transaction

    private func handleSendAction() {
        if AuthManager.shared.isAppLockEnabled {
            showAuthChallenge = true
        } else {
            confirmTransaction()
        }
    }

    private func confirmTransaction() {
        guard let wallet = walletManager.activeWallet?.zcashWallet else {
            errorMessage = "No active wallet. Please restart the app and try again."
            showErrorAlert = true
            return
        }

        isSending = true
        Task {
            let sendResult = await wallet.send(to: receiverAddress, amount: amount, memo: memo)
            switch sendResult {
            case .success:
                ReviewManager.shared.requestReviewIfEligible()
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                showSuccessSheet = true
            case .failure(let error):
                isSending = false
                errorMessage = error.userMessage
                showErrorAlert = true
            }
        }
    }

    // MARK: - Helpers

    @ViewBuilder
    private func sectionLabel(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.caption2)
            .fontWeight(.medium)
            .foregroundStyle(Color.dsTextTertiary)
            .kerning(0.8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.bottom, 8)
    }

    @ViewBuilder
    private func summaryRow<V: View>(label: String, bold: Bool = false, @ViewBuilder value: () -> V) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(label)
                .font(.subheadline)
                .fontWeight(bold ? .medium : .regular)
                .foregroundStyle(bold ? Color.dsTextPrimary : Color.dsTextSecondary)
            Spacer()
            value()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
    }

    @ViewBuilder
    private func amountStack(_ amount: CoinAmount) -> some View {
        VStack(alignment: .trailing, spacing: 2) {
            Text("\(amount.formatted(style: .full)) ZEC")
                .font(.subheadline).fontWeight(.medium)
                .foregroundStyle(Color.dsTextPrimary)
            Text("≈ \(usd(amount))")
                .font(.caption)
                .foregroundStyle(Color.dsTextSecondary)
        }
    }

    private func usd(_ amount: CoinAmount) -> String {
        String(format: "$%.2f", amount.fiat(price: zecToUsd))
    }
}

// MARK: - ZECTransactionSuccessSheet

private struct ZECTransactionSuccessSheet: View {
    let amount: CoinAmount
    let zecToUsd: Double
    let onDone: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Drag handle
            RoundedRectangle(cornerRadius: 3)
                .fill(Color.dsBorderStrong)
                .frame(width: 36, height: 4)
                .padding(.top, 12)
                .padding(.bottom, 28)

            // Checkmark icon
            ZStack {
                Circle()
                    .fill(Color.dsAccentSoft)
                    .frame(width: 72, height: 72)
                Image(systemName: "checkmark")
                    .font(.system(size: 30, weight: .bold))
                    .foregroundStyle(Color.dsAccentStrong)
            }
            .padding(.bottom, 16)

            Text("Transaction Submitted")
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundStyle(Color.dsTextPrimary)
                .padding(.bottom, 6)

            Text("\(amount.formatted(style: .full)) ZEC  ≈  \(usd(amount))")
                .font(.subheadline)
                .foregroundStyle(Color.dsTextSecondary)
                .padding(.bottom, 24)

            // Pending explanation card
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "clock")
                    .font(.subheadline)
                    .foregroundStyle(Color.dsTextSecondary)
                    .padding(.top, 1)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Pending confirmation")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(Color.dsTextPrimary)
                    Text("Your transaction has been broadcast to the Zcash network. It will appear as \"Pending\" in your history until the network confirms it, which typically takes a few minutes.")
                        .font(.caption)
                        .foregroundStyle(Color.dsTextSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.dsSurface2)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color.dsBorder, lineWidth: 1))
            .padding(.horizontal, 20)
            .padding(.bottom, 24)

            Button(action: onDone) {
                Text("Done")
            }
            .buttonStyle(.dsPrimary)
            .padding(.horizontal, 20)
            .padding(.bottom, 8)
        }
        .frame(maxWidth: .infinity)
        .background(Color.dsBackground)
        .interactiveDismissDisabled()
    }

    private func usd(_ amount: CoinAmount) -> String {
        String(format: "$%.2f", amount.fiat(price: zecToUsd))
    }
}
