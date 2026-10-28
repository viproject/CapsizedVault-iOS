//
//  SendZECView.swift
//  CapsizedVault
//

import SwiftUI
import VisionKit
import Vision

struct SendZECView: View {

    enum SendZECViewState {
        case enterAddress
        case enterAmount
        case summary
    }

    @Environment(\.dismiss) private var dismiss

    @StateObject private var walletManager = WalletManager.shared

    @State private var receiverAddress: String = ""
    @State private var showingScanner: Bool = false
    @State private var viewState: SendZECViewState = .enterAddress
    @State private var amountString = ""
    @State private var memo = ""
    @State private var isPreparingNetworkFiles = false

    @FocusState private var isEnterAddressFocused: Bool
    @State private var isEnterAmountFocused = false
    @State private var actionPanelHeight: CGFloat = 0

    private var wallet: ZECWallet? { walletManager.activeWallet?.zcashWallet }

    private var zecToUsd: Double {
        CoinPriceManager.shared.price(for: .zcash, in: .usd)
    }

    private var availableBalance: CoinAmount {
        wallet?.accounts.first?.spendable ?? .zero(.zcash)
    }

    private var isValidAddress: Bool {
        guard let wallet else { return false }
        return wallet.isValidAddress(receiverAddress.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    private var addressIsTransparent: Bool {
        wallet?.addressKind(receiverAddress.trimmingCharacters(in: .whitespacesAndNewlines)) == .transparent
    }

    var body: some View {
        VStack(spacing: 0) {
            // MARK: - Header
            ZStack {
                Text("Send ZEC")
                    .font(.headline)
                    .frame(maxWidth: .infinity, alignment: .center)

                HStack {
                    Button(action: { dismiss() }) {
                        ZStack {
                            Circle()
                                .fill(Color.dsTextPrimary.opacity(0.08))
                                .frame(width: 36, height: 36)
                            Image(systemName: "xmark")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.dsTextPrimary)
                        }
                    }
                    .buttonStyle(.dsSoft)
                    Spacer()
                }
            }
            .padding(.top, 16)
            .padding(.horizontal, 16)
            .padding(.bottom, 8)

            switch viewState {
            case .enterAddress:
                VStack(spacing: 0) {
                    enterAddressSection
                        .padding(.horizontal, 20)
                        .padding(.top, 12)
                    Spacer()
                    Button(action: nextAction) {
                        Text("Next")
                    }
                    .buttonStyle(.dsPrimary)
                    .disabled(!isNextEnabled)
                    .opacity(isNextEnabled ? 1 : 0.5)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 28)
                }

            case .enterAmount:
                ScrollView {
                    VStack(spacing: 0) {
                        enterAddressSection
                            .padding(.horizontal, 20)
                            .padding(.top, 12)
                        enterAmountSection
                            .padding(.horizontal, 20)
                        HStack(spacing: 12) {
                            Button(action: backAction) {
                                Text("Back")
                            }
                            .buttonStyle(.dsSecondary)

                            Button(action: nextAction) {
                                Text("Next")
                            }
                            .buttonStyle(.dsPrimary)
                            .disabled(!isNextEnabled)
                            .opacity(isNextEnabled ? 1 : 0.5)
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 16)
                        .padding(.bottom, 28)
                        Color.clear.frame(height: 300)
                    }
                    .instantScrollViewTouches()
                }
                .scrollDismissesKeyboard(.interactively)

            case .summary:
                summaryScreen
            }
        }
        .interactiveDismissDisabled()
        .task {
            guard let wallet else { return }
            isPreparingNetworkFiles = true
            _ = await wallet.ensureSaplingParamsDownloaded()
            isPreparingNetworkFiles = false
        }
        .task(id: FeeEstimateKey(address: receiverAddress, amount: amountString)) {
            // Debounce: rapid edits cancel the pending sleep before it fires another proposal.
            try? await Task.sleep(nanoseconds: 300_000_000)
            guard !Task.isCancelled else { return }
            await refreshEstimatedFee()
        }
        .sheet(isPresented: $showingScanner) {
            QRScannerContainerView { scannedValue in
                applyScannedOrPasted(scannedValue)
                showingScanner = false
            }
        }
    }

    // MARK: - Address Section

    private var enterAddressSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Receiver address")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.dsTextPrimary)
                .padding(.bottom, 10)

            HStack(alignment: viewState == .enterAddress ? .top : .center, spacing: 12) {

                VStack(alignment: .leading, spacing: 8) {
                    if viewState == .enterAddress {
                        TextField("Paste or scan an address", text: $receiverAddress, axis: .vertical)
                            .focused($isEnterAddressFocused)
                            .font(.system(size: 14, weight: .regular, design: .monospaced))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .frame(height: actionPanelHeight > 0 ? actionPanelHeight : nil, alignment: .topLeading)
                            .background(
                                Color.dsSurface2
                                    .onTapGesture { isEnterAddressFocused = true }
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .strokeBorder(
                                        !receiverAddress.isEmpty && !isValidAddress
                                            ? Color.dsDanger
                                            : Color.dsBorder,
                                        lineWidth: 1
                                    )
                            )
                            .onChange(of: receiverAddress) { _ in
                                let stripped = receiverAddress.replacingOccurrences(of: "\n", with: "")
                                if stripped != receiverAddress {
                                    receiverAddress = stripped
                                    isEnterAddressFocused = false
                                }
                            }
                    } else {
                        Text(receiverAddress)
                            .font(.system(size: 13, weight: .regular, design: .monospaced))
                            .foregroundStyle(Color.dsTextSecondary)
                            .lineLimit(4)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(14)
                            .background(Color.dsSurface2)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .strokeBorder(Color.dsBorder, lineWidth: 1)
                            )
                    }

                    if !receiverAddress.isEmpty && !isValidAddress {
                        Text("Invalid Zcash address")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Color.dsDanger)
                    }

                    if viewState == .enterAddress && !receiverAddress.isEmpty {
                        HStack {
                            Spacer()
                            Button {
                                receiverAddress = ""
                            } label: {
                                Label("Clear", systemImage: "xmark")
                                    .font(.system(size: 13, weight: .semibold))
                            }
                            .foregroundStyle(Color.dsDanger)
                            .buttonStyle(.dsSoft)
                        }
                    }
                }

                if viewState == .enterAddress {
                    // QR / Paste action panel
                    VStack(spacing: 18) {
                        VStack(spacing: 4) {
                            Button(action: scanQRCode) {
                                Image(systemName: "qrcode.viewfinder")
                                    .font(.system(size: 18))
                                    .foregroundStyle(Color.dsAccent)
                                    .frame(width: 44, height: 44)
                                    .background(Color.dsJadeSoft)
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                            }
                            .buttonStyle(.dsSoft)
                            Text("Scan")
                                .font(.system(size: 11))
                                .foregroundStyle(Color.dsTextTertiary)
                        }

                        VStack(spacing: 4) {
                            Button(action: pasteAddress) {
                                Image(systemName: "document.on.clipboard")
                                    .font(.system(size: 18))
                                    .foregroundStyle(Color.dsAccent)
                                    .frame(width: 44, height: 44)
                                    .background(Color.dsJadeSoft)
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                            }
                            .buttonStyle(.dsSoft)
                            Text("Paste")
                                .font(.system(size: 11))
                                .foregroundStyle(Color.dsTextTertiary)
                        }
                    }
                    .padding(.vertical, 10)
                    .padding(.horizontal, 6)
                    .background(Color.dsSurface2)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .strokeBorder(Color.dsBorder, lineWidth: 1)
                    )
                    .overlay(
                        GeometryReader { geo in
                            Color.clear.onAppear { actionPanelHeight = geo.size.height }
                        }
                        .allowsHitTesting(false)
                    )
                } else {
                    VStack(spacing: 4) {
                        Button(action: backAction) {
                            Image(systemName: "pencil")
                                .font(.system(size: 16))
                                .foregroundStyle(Color.dsAccent)
                                .frame(width: 44, height: 44)
                                .background(Color.dsJadeSoft)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                        .buttonStyle(.dsSoft)
                        Text("Edit")
                            .font(.system(size: 11))
                            .foregroundStyle(Color.dsTextTertiary)
                    }
                }
            }

            if addressIsTransparent {
                Text("Transparent addresses are visible on the public blockchain.")
                    .font(.system(size: 12))
                    .foregroundStyle(Color(red: 0.698, green: 0.561, blue: 0.251))
                    .padding(.top, 8)
            }
        }
    }

    // MARK: - Computed properties for amount section

    private var amountBinding: Binding<String> {
        Binding(
            get: { amountString },
            set: { raw in
                guard raw.allSatisfy({ "0123456789.".contains($0) }) else { return }
                var filtered = raw.filter { "0123456789.".contains($0) }
                let parts = filtered.components(separatedBy: ".")
                if parts.count > 2 {
                    filtered = parts[0] + "." + parts[1]
                }
                if let dotIndex = filtered.firstIndex(of: ".") {
                    let decimals = filtered.distance(from: filtered.index(after: dotIndex), to: filtered.endIndex)
                    if decimals > Coin.zcash.decimals {
                        filtered = String(filtered[..<filtered.index(dotIndex, offsetBy: Coin.zcash.decimals + 1)])
                    }
                }
                amountString = filtered
            }
        )
    }

    private var amount: CoinAmount {
        CoinAmount(parsing: amountString, coin: .zcash) ?? .zero(.zcash)
    }

    /// Updated by the debounced `.task(id:)` below.
    @State private var estimatedFee: CoinAmount = .zero(.zcash)

    private struct FeeEstimateKey: Equatable {
        let address: String
        let amount: String
    }

    private func refreshEstimatedFee() async {
        guard !receiverAddress.isEmpty, isValidAddress, let wallet else {
            estimatedFee = .zero(.zcash)
            return
        }
        let result = await wallet.estimateFee(to: receiverAddress.trimmingCharacters(in: .whitespacesAndNewlines), amount: amount)
        if case .success(let fee) = result {
            estimatedFee = fee
        }
    }

    private func usd(_ amount: CoinAmount) -> String {
        String(format: "$%.2f USD", amount.fiat(price: zecToUsd))
    }

    // MARK: - Amount Section

    private var enterAmountSection: some View {
        VStack(spacing: 0) {
            Text("Enter amount")
                .font(.system(size: 15))
                .foregroundStyle(Color.dsTextTertiary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 28)
                .padding(.bottom, 4)

            VStack(spacing: 0) {
                HStack(alignment: .lastTextBaseline, spacing: 8) {
                    ZECAmountInputField(
                        text: amountBinding,
                        isFocused: $isEnterAmountFocused,
                        fontSize: amountString.count > 9 ? 30 : 46,
                        textColor: UIColor(amount.isZero ? Color.dsTextTertiary : Color.dsTextPrimary),
                        onDone: { isEnterAmountFocused = false }
                    )
                    Text("ZEC")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.dsTextTertiary)
                }

                Rectangle()
                    .frame(height: 2)
                    .foregroundStyle(isEnterAmountFocused ? Color.dsAccent : Color.clear)
                    .animation(.easeInOut(duration: 0.12), value: isEnterAmountFocused)
                    .padding(.top, 6)

                Text("≈ \(usd(amount))")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.dsTextTertiary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 6)
            }
            .padding(.vertical, 24)
            .onTapGesture {
                isEnterAmountFocused = true
            }

            if !addressIsTransparent {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Memo")
                            .font(.system(size: 13))
                            .foregroundStyle(Color.dsTextTertiary)
                        Spacer()
                        Text("\(memo.utf8.count)/512")
                            .font(.system(size: 11))
                            .foregroundStyle(Color.dsTextTertiary)
                    }
                    TextField("", text: $memo)
                        .font(.system(size: 14))
                        .padding(.horizontal, 14)
                        .frame(height: 44)
                        .background(Color.dsSurface2)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .strokeBorder(Color.dsBorder, lineWidth: 1)
                        )
                        .onChange(of: memo) { _ in
                            while memo.utf8.count > 512 { memo = String(memo.dropLast()) }
                        }
                }
                .padding(.vertical, 16)
            }

            if isPreparingNetworkFiles {
                HStack(spacing: 8) {
                    ProgressView()
                    Text("Preparing Zcash network files (one-time, ~50MB)…")
                        .font(.caption)
                        .foregroundStyle(Color.dsTextTertiary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.bottom, 12)
            }

            if !amount.isZero && amount.atomic + estimatedFee.atomic > availableBalance.atomic {
                Text("Insufficient balance to cover amount + fee")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.dsDanger)
                    .multilineTextAlignment(.center)
                    .padding(.bottom, 12)
            }

            Divider()

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Available")
                        .font(.caption)
                        .foregroundStyle(Color.dsTextTertiary)
                    Text("\(availableBalance.formatted(style: .balance)) ZEC")
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundStyle(Color.dsTextPrimary)
                }
                Spacer()
            }
            .padding(.vertical, 16)

            Divider()

            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Estimated fee")
                        .font(.caption)
                        .foregroundStyle(Color.dsTextTertiary)
                    Text("\(estimatedFee.formatted(style: .full)) ZEC")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(Color.dsTextPrimary)
                    Text("≈ \(usd(estimatedFee))")
                        .font(.caption)
                        .foregroundStyle(Color.dsTextTertiary)
                }
                Spacer()
            }
            .padding(.vertical, 16)
        }
    }

    private var summaryScreen: some View {
        SendZECSummaryView(
            receiverAddress: receiverAddress.trimmingCharacters(in: .whitespacesAndNewlines),
            amount: amount,
            availableBalance: availableBalance,
            estimatedFee: estimatedFee,
            zecToUsd: zecToUsd,
            memo: addressIsTransparent ? nil : (memo.isEmpty ? nil : memo)
        ) {
            backAction()
        }
    }

    private var isNextEnabled: Bool {
        if viewState == .enterAddress {
            return !receiverAddress.isEmpty && isValidAddress
        } else if viewState == .enterAmount {
            return !amount.isZero && amount.atomic + estimatedFee.atomic <= availableBalance.atomic
        }
        return true
    }

    private func scanQRCode() {
        showingScanner = true
    }

    private func pasteAddress() {
        if let value = UIPasteboard.general.string {
            applyScannedOrPasted(value)
        }
    }

    /// Both a scanned QR and a pasted clipboard value might be a bare address or a ZIP-321
    /// `zcash:` payment URI — either way this fills in whatever fields the value carries.
    private func applyScannedOrPasted(_ value: String) {
        if let request = ZIP321.parse(value) {
            receiverAddress = request.address
            if let requestedAmount = request.amount { amountString = requestedAmount }
            if let requestedMemo = request.memo { memo = requestedMemo }
        } else {
            receiverAddress = value.trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }

    private func nextAction() {
        switch viewState {
        case .enterAddress:
            if !receiverAddress.isEmpty && isValidAddress {
                viewState = .enterAmount
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    isEnterAmountFocused = true
                }
            }
        case .enterAmount:
            viewState = .summary
        case .summary:
            break
        }
    }

    private func backAction() {
        switch viewState {
        case .enterAddress:
            break
        case .enterAmount:
            viewState = .enterAddress
        case .summary:
            viewState = .enterAmount
        }
    }
}

// MARK: - UITextField subclass: blocks paste if any character is not a digit or "."

private class ZECAmountTextField: UITextField {
    override func paste(_ sender: Any?) {
        guard let string = UIPasteboard.general.string,
              string.allSatisfy({ "0123456789.".contains($0) }) else { return }
        super.paste(sender)
    }
}

// MARK: - SwiftUI wrapper for ZECAmountTextField

private struct ZECAmountInputField: UIViewRepresentable {
    @Binding var text: String
    @Binding var isFocused: Bool
    var fontSize: CGFloat
    var textColor: UIColor
    var onDone: () -> Void

    func makeUIView(context: Context) -> ZECAmountTextField {
        let field = ZECAmountTextField()
        field.keyboardType = .decimalPad
        field.textAlignment = .right
        field.adjustsFontSizeToFitWidth = true
        field.autocorrectionType = .no
        field.attributedPlaceholder = NSAttributedString(
            string: "0",
            attributes: [.foregroundColor: UIColor(Color.dsTextTertiary)]
        )
        field.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        field.setContentHuggingPriority(.defaultLow, for: .horizontal)
        field.delegate = context.coordinator
        field.addTarget(context.coordinator, action: #selector(Coordinator.textDidChange(_:)), for: .editingChanged)

        let toolbar = UIToolbar()
        toolbar.sizeToFit()
        let spacer = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
        let done = UIBarButtonItem(title: "Done", style: .plain, target: context.coordinator, action: #selector(Coordinator.doneTapped))
        done.setTitleTextAttributes([
            .font: UIFont.systemFont(ofSize: 16, weight: .semibold),
            .foregroundColor: UIColor(Color.dsAccent)
        ], for: .normal)
        toolbar.items = [spacer, done]
        field.inputAccessoryView = toolbar
        return field
    }

    func updateUIView(_ field: ZECAmountTextField, context: Context) {
        if field.text != text { field.text = text }
        field.textColor = textColor
        field.minimumFontSize = fontSize * 0.4
        let base = UIFont.systemFont(ofSize: fontSize, weight: .bold)
        if let rounded = base.fontDescriptor.withDesign(.rounded) {
            field.font = UIFont(descriptor: rounded, size: fontSize)
        } else {
            field.font = base
        }
        if isFocused, !field.isFirstResponder {
            DispatchQueue.main.async { field.becomeFirstResponder() }
        } else if !isFocused, field.isFirstResponder {
            field.resignFirstResponder()
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator(text: $text, isFocused: $isFocused, onDone: onDone) }

    final class Coordinator: NSObject, UITextFieldDelegate {
        @Binding var text: String
        @Binding var isFocused: Bool
        let onDone: () -> Void

        init(text: Binding<String>, isFocused: Binding<Bool>, onDone: @escaping () -> Void) {
            _text = text; _isFocused = isFocused; self.onDone = onDone
        }

        @objc func textDidChange(_ field: UITextField) { text = field.text ?? "" }
        @objc func doneTapped() { onDone() }
        func textFieldDidBeginEditing(_: UITextField) { isFocused = true }
        func textFieldDidEndEditing(_: UITextField) { isFocused = false }
    }
}
