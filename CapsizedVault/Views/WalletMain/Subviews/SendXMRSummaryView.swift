import SwiftUI
import CapsizedMoneroKit
import LocalAuthentication

struct SendXMRSummaryView: View {

    let receiverAddress: String
    let amount: Double
    let sendAll: Bool
    let availableBalance: Double
    let estimatedFee: Double
    let transactionPriority: XMRWallet.XMRSendPriority
    let xmrToUsd: Double
    let memo: String

    let backAction: () -> Void

    private var displayAmount: Double { sendAll ? amount - estimatedFee : amount }
    private var total: Double { sendAll ? amount : amount + estimatedFee }
    private var balanceAfter: Double { availableBalance - total }
    
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
                        Text(displayAmount.xmrFormatted)
                            .font(.system(size: 38, weight: .medium, design: .rounded))
                            .foregroundStyle(Color.dsTextPrimary)
                        Text("XMR")
                            .font(.title3)
                            .fontWeight(.medium)
                            .foregroundStyle(Color.dsTextSecondary)
                    }
                    Text("≈ \(usd(displayAmount))")
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
                        amountStack(xmr: displayAmount)
                    }
                    Divider().padding(.leading, 16)
                    HStack(alignment: .top, spacing: 12) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Fee")
                                .font(.subheadline)
                                .foregroundStyle(Color.dsTextSecondary)
                            Text("\(transactionPriority.description.capitalized) priority")
                                .font(.caption)
                                .foregroundStyle(Color.dsTextTertiary)
                        }
                        Spacer()
                        amountStack(xmr: estimatedFee)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 13)
                    Divider()
                    summaryRow(label: "Total", bold: true) {
                        amountStack(xmr: total)
                    }
                    .background(Color.dsSurface)
                }
                .background(Color.dsSurface2)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Color.dsBorder, lineWidth: 1))
                .padding(.bottom, 12)

                // MARK: - Memo Card
                if !memo.isEmpty {
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
                            Text("\(availableBalance.xmrFormatted) XMR")
                                .font(.subheadline).fontWeight(.medium)
                                .foregroundStyle(Color.dsTextPrimary)
                            Text("after: \(balanceAfter.xmrFormatted) XMR")
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
                    Text("Monero transactions are irreversible. Please verify the recipient address before confirming.")
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
            TransactionSuccessSheet(displayAmount: displayAmount, xmrToUsd: xmrToUsd) {
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
        guard let wallet = walletManager.activeWallet else {
            errorMessage = "No active wallet. Please restart the app and try again."
            showErrorAlert = true
            return
        }

        isSending = true
        Task {
            let sendResult = await wallet.send(
                to: receiverAddress,
                amount: amount,
                sendAll: sendAll,
                priority: transactionPriority.sendPriority,
                memo: memo.isEmpty ? nil : memo
            )
            switch sendResult {
            case .success:
                ReviewManager.shared.requestReviewIfEligible()
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                showSuccessSheet = true
            case .failure(let error):
                isSending = false
                errorMessage = sendErrorMessage(error)
                showErrorAlert = true
            }
        }
    }

    private func sendErrorMessage(_ error: Error) -> String {
        guard let coreError = error as? MoneroCoreError else {
            return error.localizedDescription
        }
        switch coreError {
        case .walletNotInitialized:
            return "Wallet is not initialized. Please try again."
        case .insufficientFunds(let balance):
            return "Insufficient funds. Available balance: \(balance) XMR."
        case .transactionSendFailed(let msg):
            return "Failed to send transaction: \(msg)"
        case .transactionCommitFailed(let msg):
            return "Transaction could not be committed: \(msg)"
        case .transactionEstimationFailed(let msg):
            return "Fee estimation failed: \(msg)"
        default:
            return error.localizedDescription
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
    private func amountStack(xmr: Double) -> some View {
        VStack(alignment: .trailing, spacing: 2) {
            Text("\(xmr.xmrFormatted) XMR")
                .font(.subheadline).fontWeight(.medium)
                .foregroundStyle(Color.dsTextPrimary)
            Text("≈ \(usd(xmr))")
                .font(.caption)
                .foregroundStyle(Color.dsTextSecondary)
        }
    }

    private func usd(_ xmr: Double) -> String {
        let usd = xmr * xmrToUsd
        return String(format: "$%.2f", usd)
    }
}
// MARK: - TransactionSuccessSheet

private struct TransactionSuccessSheet: View {
    let displayAmount: Double
    let xmrToUsd: Double
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

            Text("\(displayAmount.xmrFormatted) XMR  ≈  \(usd(displayAmount))")
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
                    Text("Your transaction has been broadcast to the Monero network. It will appear as \"Pending\" in your history until the network confirms it, which typically takes a few minutes.")
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

    private func usd(_ xmr: Double) -> String {
        String(format: "$%.2f", xmr * xmrToUsd)
    }
}

// MARK: - HoldTimer

private final class HoldTimer {
    var timer: Timer?

    func start(interval: TimeInterval, block: @escaping (Timer) -> Void) {
        guard timer == nil else { return }
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true, block: block)
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }
}

// MARK: - HoldToSendButton

private struct HoldToSendButton: View {
    let isSending: Bool
    let showError: Bool
    let resetTrigger: Int
    let action: () -> Void

    @State private var progress: CGFloat = 0
    @State private var didFire = false
    @State private var timerHolder = HoldTimer()

    private let holdDuration: Double = 1.5
    private let tickInterval: Double = 1.0 / 60.0

    var body: some View {
        ZStack {
            // Background track
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.dsAccent.opacity(0.5))

            // Progress fill — plain Rectangle clipped to rounded shape so the
            // right edge stays straight while filling, rounds fully when complete
            GeometryReader { geo in
                Rectangle()
                    .fill(Color.dsAccent)
                    .frame(width: geo.size.width * progress, height: geo.size.height)
            }
            .clipShape(RoundedRectangle(cornerRadius: 14))

            // Label
            if isSending {
                ProgressView()
                    .tint(.white)
            } else {
                HStack(spacing: 8) {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 14, weight: .semibold))
                    Text(progress > 0 ? "Keep holding..." : "Hold to send")
                        .fontWeight(.semibold)
                }
                .foregroundStyle(.white)
            }
        }
        .frame(height: 52)
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in startHolding() }
                .onEnded { _ in endHolding() }
        )
        .disabled(isSending)
        // Reset when a send error is shown.
        .onChange(of: showError) { hasError in
            if hasError {
                didFire = false
                progress = 0
            }
        }
        // Reset when auth is cancelled so the user can hold again.
        .onChange(of: resetTrigger) { _ in
            didFire = false
            withAnimation(.easeOut(duration: 0.3)) { progress = 0 }
        }
    }

    private func startHolding() {
        guard !didFire, !isSending else { return }
        timerHolder.start(interval: tickInterval) { _ in
            let increment = CGFloat(tickInterval / holdDuration)
            if progress + increment >= 1.0 {
                progress = 1.0
                timerHolder.stop()
                didFire = true
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                action()
            } else {
                progress += increment
            }
        }
    }

    private func endHolding() {
        timerHolder.stop()
        guard !didFire else { return }
        withAnimation(.easeOut(duration: 0.3)) {
            progress = 0
        }
    }
}

// MARK: - TransactionAuthView

private struct TransactionAuthView: View {
    let onAuthenticated: () -> Void
    let onCancel: () -> Void

    @StateObject private var authManager = AuthManager.shared
    @State private var showPIN: Bool
    @State private var errorMessage: String?

    init(onAuthenticated: @escaping () -> Void, onCancel: @escaping () -> Void) {
        self.onAuthenticated = onAuthenticated
        self.onCancel = onCancel
        let hasBiometric = AuthManager.shared.isBiometricEnabled && AuthManager.shared.isBiometricAvailable
        _showPIN = State(initialValue: !hasBiometric)
    }

    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()
            if showPIN {
                pinView
            } else {
                biometricView
            }
        }
        .task {
            guard !showPIN else { return }
            await attemptBiometric()
        }
    }

    // MARK: Biometric view

    private var biometricView: some View {
        VStack(spacing: 24) {
            HStack {
                Spacer()
                Button("Cancel", action: onCancel)
                    .font(.body)
                    .foregroundStyle(Color.dsTextSecondary)
                    .padding()
            }

            Spacer()

            Image(systemName: "arrow.up.circle")
                .font(.system(size: 52))
                .foregroundStyle(Color.dsAccent)

            Text("Confirm Transaction")
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundStyle(Color.dsTextPrimary)

            Button {
                Task { await attemptBiometric() }
            } label: {
                Label("Use \(authManager.biometricName)", systemImage: biometricIcon)
                    .font(.headline)
                    .padding(.vertical, 14)
                    .padding(.horizontal, 24)
                    .background(Color.primary)
                    .foregroundStyle(Color(.systemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            Button("Use PIN") { showPIN = true }
                .font(.subheadline)
                .foregroundStyle(Color.dsTextSecondary)

            Spacer()
        }
    }

    // MARK: PIN view

    private var pinView: some View {
        VStack {
            HStack {
                Button {
                    if authManager.isBiometricEnabled && authManager.isBiometricAvailable {
                        showPIN = false
                    } else {
                        onCancel()
                    }
                } label: {
                    if authManager.isBiometricEnabled && authManager.isBiometricAvailable {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundStyle(Color.dsTextPrimary)
                    } else {
                        Text("Cancel")
                            .font(.body)
                            .foregroundStyle(Color.dsTextSecondary)
                    }
                }
                Spacer()
            }
            .padding()

            PINEntryView(title: "Enter PIN", errorMessage: $errorMessage) { pin in
                if KeychainHelper.verifyPIN(pin) {
                    errorMessage = nil
                    onAuthenticated()
                } else {
                    errorMessage = "Incorrect PIN. Try again."
                }
            }
        }
    }

    private var biometricIcon: String {
        switch authManager.biometricType {
        case .faceID: return "faceid"
        case .touchID: return "touchid"
        default: return "lock.shield"
        }
    }

    private func attemptBiometric() async {
        let success = await authManager.evaluateBiometrics(reason: "Confirm transaction")
        if success {
            onAuthenticated()
        } else {
            showPIN = true
        }
    }
}

