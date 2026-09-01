//
//  SendXMRView.swift
//  CapsizedVault
//
//  Created by Dmitrij on 14/04/2026.
//

import SwiftUI
import VisionKit
import Vision
import CapsizedMoneroKit

struct SendXMRView: View {
    
    enum SendXMRViewState {
        case enterAddress
        case enterAmount
        case summary
    }
    
    @Environment(\.dismiss) private var dismiss
    
    @StateObject private var walletManager = WalletManager.shared
    
    @State private var receiverAddress: String = ""
    @State private var showingScanner: Bool = false
    @State private var viewState: SendXMRViewState = .enterAddress
    @State private var amountString = ""
    @State private var sendAll = false
    @State private var transactionPriority: XMRWallet.XMRSendPriority = .default
    @State private var memo = ""
    
    private var xmrToUsd: Double {
        CoinPriceManager.shared.price(for: .monero, in: .usd)
    }
    private var availableBalance: Double {
        Double(walletManager.activeWallet?.activeBalance.unlocked ?? 0) / 1_000_000_000_000
    }
    
    @FocusState private var isEnterAddressFocused: Bool
    @State private var isEnterAmountFocused = false
    @State private var actionPanelHeight: CGFloat = 0
    
    // Fixed: both prefixes require count == 95
    var isValidAddress: Bool {
        let trimmed = receiverAddress.trimmingCharacters(in: .whitespacesAndNewlines)
        return (trimmed.hasPrefix("4") || trimmed.hasPrefix("8")) && trimmed.count == 95
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // MARK: - Header
            ZStack {
                Text("Send XMR")
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
                        // Extra space so there is always enough content below the memo
                        // field for the scroll view to scroll it fully above the keyboard.
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
        .sheet(isPresented: $showingScanner) {
            QRScannerContainerView { scannedValue in
                var address = scannedValue
                if address.hasPrefix("monero:") {
                    address = String(address.dropFirst("monero:".count))
                }
                receiverAddress = address
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
                        Text("Invalid Monero address")
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
                    // Edit address button
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
        }
    }
    
    // MARK: - Computed properties for amount section

    /// Binding that sanitizes on set: only ASCII digits + one decimal point + max 12 decimal places.
    private var amountBinding: Binding<String> {
        Binding(
            get: { amountString },
            set: { raw in
                // Reject any input that contains characters outside the valid set (e.g. a paste with letters)
                guard raw.allSatisfy({ "0123456789.".contains($0) }) else { return }
                // Strip everything except ASCII digits and "."
                var filtered = raw.filter { "0123456789.".contains($0) }
                // Allow only one decimal point
                let parts = filtered.components(separatedBy: ".")
                if parts.count > 2 {
                    filtered = parts[0] + "." + parts[1]
                }
                // Cap to 12 decimal places
                if let dotIndex = filtered.firstIndex(of: ".") {
                    let decimals = filtered.distance(from: filtered.index(after: dotIndex), to: filtered.endIndex)
                    if decimals > 12 {
                        filtered = String(filtered[..<filtered.index(dotIndex, offsetBy: 13)])
                    }
                }
                amountString = filtered
            }
        )
    }

    private var amountDouble: Double {
        Double(amountString) ?? 0
    }
    
    private var estimatedFeeDouble: Double {
        walletManager.activeWallet?.estimateFeeDouble(address: receiverAddress, amount: amountDouble, priority: transactionPriority) ?? 0
    }
    
    private var estimatedFeeString: String {
        guard !receiverAddress.isEmpty && isValidAddress else {
            return "0 XMR"
        }
        return "\(estimatedFeeDouble.xmrFormatted) XMR"
    }
    
    private var usdEquivalentFee: String {
        String(format: "$%.2f USD", estimatedFeeDouble * xmrToUsd)
    }
    
    private var usdEquivalentAmount: String {
        String(format: "$%.2f USD", amountDouble * xmrToUsd)
    }
    
    // MARK: - Amount Section
    
    private var enterAmountSection: some View {
        VStack(spacing: 0) {
            
            // MARK: - Header
            Text("Enter amount")
                .font(.system(size: 15))
                .foregroundStyle(Color.dsTextTertiary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 28)
                .padding(.bottom, 4)
            
            // MARK: - Amount Input
            VStack(spacing: 0) {
                HStack(alignment: .lastTextBaseline, spacing: 8) {
                    AmountInputField(
                        text: amountBinding,
                        isFocused: $isEnterAmountFocused,
                        fontSize: amountString.count > 9 ? 30 : 46,
                        textColor: UIColor(amountDouble > 0 ? Color.dsTextPrimary : Color.dsTextTertiary),
                        onDone: { isEnterAmountFocused = false }
                    )
                    .onChange(of: amountString) { _ in
                        if isEnterAmountFocused { sendAll = false }
                    }
                    Text("XMR")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.dsTextTertiary)
                }
                
                // Focus underline
                Rectangle()
                    .frame(height: 2)
                    .foregroundStyle(isEnterAmountFocused ? Color.dsAccent : Color.clear)
                    .animation(.easeInOut(duration: 0.12), value: isEnterAmountFocused)
                    .padding(.top, 6)
                
                Text("≈ \(usdEquivalentAmount)")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.dsTextTertiary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 6)
            }
            .padding(.vertical, 24)
            .onTapGesture {
                isEnterAmountFocused = true
            }
            
            // MARK: - Memo
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Memo")
                        .font(.system(size: 13))
                        .foregroundStyle(Color.dsTextTertiary)
                    Spacer()
                    Text("\(memo.count)/100")
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
                        if memo.count > 100 { memo = String(memo.prefix(100)) }
                    }
            }
            .padding(.vertical, 16)

            if !sendAll && amountDouble > 0 && amountDouble + estimatedFeeDouble > availableBalance {
                Text("Insufficient balance to cover amount + fee")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.dsDanger)
                    .multilineTextAlignment(.center)
                    .padding(.bottom, 12)
            }
            
            Divider()
            
            // MARK: - Available Balance
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Available")
                        .font(.caption)
                        .foregroundStyle(Color.dsTextTertiary)
                    Text("\(availableBalance.xmrFormatted) XMR")
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundStyle(Color.dsTextPrimary)
                }
                
                Spacer()
                
                Button {
                    amountString = availableBalance.xmrFormatted
                    sendAll = true
                    isEnterAmountFocused = false
                } label: {
                    Text("Max")
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.dsJadeSoft)
                        .foregroundStyle(Color.dsAccent)
                        .clipShape(Capsule())
                }
                .buttonStyle(.dsSoft)
            }
            .padding(.vertical, 16)
            
            if sendAll {
                Text("Max sends your full balance minus the network fee.")
                    .font(.caption)
                    .foregroundStyle(Color.dsTextTertiary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.bottom, 12)
            }
            
            Divider()
            
            // MARK: - Estimated Fee
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Estimated fee")
                        .font(.caption)
                        .foregroundStyle(Color.dsTextTertiary)
                    Text(estimatedFeeString)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(Color.dsTextPrimary)
                    Text("≈ \(usdEquivalentFee)")
                        .font(.caption)
                        .foregroundStyle(Color.dsTextTertiary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 6) {
                    Text("Priority")
                        .font(.caption)
                        .foregroundStyle(Color.dsTextTertiary)
                    
                    Button {
                        // empty — tap handled by Menu overlay
                    } label: {
                        HStack(spacing: 6) {
                            Text(transactionPriority.description)
                                .font(.subheadline)
                                .fontWeight(.bold)
                            Image(systemName: "chevron.up.chevron.down")
                                .font(.system(size: 10))
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.dsJadeSoft)
                        .foregroundStyle(Color.dsAccent)
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.dsSoft)
                    .contextMenu {
                        // empty — prevents default long-press menu
                    }
                    .overlay {
                        Menu {
                            ForEach(XMRWallet.XMRSendPriority.allCases, id: \.self) { priority in
                                Button {
                                    transactionPriority = priority
                                } label: {
                                    HStack {
                                        Text(priority.description.capitalized)
                                        if transactionPriority == priority {
                                            Image(systemName: "checkmark")
                                        }
                                    }
                                }
                            }
                        } label: {
                            Color.clear
                        }
                    }
                }
            }
            .padding(.vertical, 16)

        }
    }

    private var summaryScreen: some View {
        SendXMRSummaryView(
            receiverAddress: receiverAddress,
            amount: amountDouble,
            sendAll: sendAll,
            availableBalance: availableBalance,
            estimatedFee: estimatedFeeDouble,
            transactionPriority: transactionPriority,
            xmrToUsd: xmrToUsd,
            memo: memo
        ) {
            backAction()
        }
    }
    
    private var isNextEnabled: Bool {
        if viewState == .enterAddress {
            return !receiverAddress.isEmpty && isValidAddress
        } else if viewState == .enterAmount {
            if sendAll { return true }
            return amountDouble > 0 && amountDouble + estimatedFeeDouble <= availableBalance
        }
        return true
    }
    
    private func scanQRCode() {
        showingScanner = true
    }
    
    private func pasteAddress() {
        if let address = UIPasteboard.general.string {
            receiverAddress = address.trimmingCharacters(in: .whitespacesAndNewlines)
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

private class AmountTextField: UITextField {
    override func paste(_ sender: Any?) {
        guard let string = UIPasteboard.general.string,
              string.allSatisfy({ "0123456789.".contains($0) }) else { return }
        super.paste(sender)
    }
}

// MARK: - SwiftUI wrapper for AmountTextField

private struct AmountInputField: UIViewRepresentable {
    @Binding var text: String
    @Binding var isFocused: Bool
    var fontSize: CGFloat
    var textColor: UIColor
    var onDone: () -> Void

    func makeUIView(context: Context) -> AmountTextField {
        let field = AmountTextField()
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

        // Done button as inputAccessoryView
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

    func updateUIView(_ field: AmountTextField, context: Context) {
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
