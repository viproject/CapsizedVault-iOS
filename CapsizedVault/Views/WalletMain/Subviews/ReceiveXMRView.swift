//
//  ReceiveXMRView.swift
//  CapsizedVault
//
//  Created by Dmitrij on 19/03/2026.
//

import SwiftUI
import QRCode

struct ReceiveXMRView: View {

    @StateObject private var walletManager = WalletManager.shared
    @StateObject private var priceManager = CoinPriceManager.shared
    @AppStorage("balanceVisible") private var balanceVisible = true
    @State private var selectedSubaddress = WalletManager.shared.activeWallet?.activeSubaddresses.first?.0 ?? ""
    @State private var showingShareOptions = false
    @State private var showingAccountSheet = false
    @State private var shareContent: ShareableContent?
    @State private var showingLabelInput = false
    @State private var newSubaddressLabel = ""
    @State private var showingEditLabel = false
    @State private var editLabelText = ""
    @State private var editingSubaddressIndex: Int?
    @State private var newestSubaddressAddress: String? = nil
    @State private var qrExpanded = false
    @State private var qrImageCopied = false
    @State private var didCopyOrShare = false

    private var qrDocument: QRCode.Document {
        let doc = try! QRCode.Document(utf8String: selectedSubaddress)
        doc.errorCorrection = .medium
        doc.design.foregroundColor(CGColor(red: 0.420, green: 0.478, blue: 0.165, alpha: 1.0))
        doc.design.backgroundColor(CGColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0))
        doc.design.shape.onPixels = QRCode.PixelShape.RoundedPath(cornerRadiusFraction: 0.7, hasInnerCorners: true)
        doc.design.shape.eye = QRCode.EyeShape.RoundedRect()
        return doc
    }

    private var activeAddressLabel: String {
        guard let subaddresses = walletManager.activeWallet?.activeSubaddresses else { return "" }
        if let match = subaddresses.first(where: { $0.0 == selectedSubaddress }) {
            if match.1 == 0 { return "#0 PRIMARY ACCOUNT" }
            return match.3.isEmpty
                ? "#\(match.1) GENERATED"
                : "#\(match.1) \(match.3.uppercased())"
        }
        return ""
    }

    var body: some View {
        VStack(spacing: 0) {
            // MARK: - Header (fixed, not scrolling)
            ZStack {
                Text("Receive XMR")
                    .font(.system(size: 19, weight: .bold))
                    .foregroundStyle(Color.dsTextPrimary)
                    .frame(maxWidth: .infinity, alignment: .center)

                HStack {
                    Spacer()
                    if !selectedSubaddress.isEmpty {
                        Button {
                            showingShareOptions = true
                        } label: {
                            Image(systemName: "square.and.arrow.up")
                                .font(.system(size: 18))
                                .foregroundStyle(Color.dsAccentStrong)
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 14)

            // MARK: - Scrollable Content
            ScrollView {
                VStack(spacing: 0) {

                    // QR Code + tap-to-enlarge
                    VStack(spacing: 10) {
                        Button {
                            qrExpanded = true
                        } label: {
                            QRCodeDocumentUIView(document: qrDocument)
                                .frame(width: 200, height: 200)
                                .clipShape(RoundedRectangle(cornerRadius: 20))
                        }
                        .buttonStyle(.plain)

                        Button {
                            qrExpanded = true
                        } label: {
                            HStack(spacing: 5) {
                                Image(systemName: "arrow.up.left.and.arrow.down.right")
                                    .font(.system(size: 11))
                                Text("Tap to enlarge")
                                    .font(.system(size: 12, weight: .semibold))
                            }
                            .foregroundStyle(Color.dsAccentStrong)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.top, 24)

                    Divider()
                        .padding(.top, 20)

                    // Account switcher
                    if let activeWallet = walletManager.activeWallet {
                        accountSwitcherButton(activeWallet)
                            .padding(.top, 20)
                    }

                    // New Subaddress button
                    Button {
                        newSubaddressLabel = ""
                        showingLabelInput = true
                    } label: {
                        Text("New Subaddress")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Color.dsTextOnAccent)
                            .frame(minWidth: 220)
                            .padding(.vertical, 14)
                            .background(Color.dsAccent)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 16)

                    Text("New subaddress is generated each time you use one.\nAll subaddresses continue to work.")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.dsTextTertiary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                        .padding(.top, 16)

                    // Subaddress list
                    VStack(spacing: 10) {
                        if let subaddresses = walletManager.activeWallet?.activeSubaddresses {
                            ForEach(subaddresses.indices, id: \.self) { i in
                                let addr = subaddresses[i]
                                let labelStr = addr.1 == 0
                                    ? "#0 PRIMARY ACCOUNT"
                                    : (addr.3.isEmpty ? "#\(addr.1) GENERATED" : "#\(addr.1) \(addr.3.uppercased())")

                                ReceiveSubaddressRow(
                                    label: labelStr,
                                    value: addr.0,
                                    txCount: addr.2,
                                    highlighted: newestSubaddressAddress == addr.0,
                                    selected: selectedSubaddress == addr.0,
                                    onCopy: { didCopyOrShare = true }
                                )
                                .onTapGesture {
                                    selectedSubaddress = addr.0
                                }
                                .contextMenu {
                                    Button {
                                        editingSubaddressIndex = addr.1
                                        editLabelText = addr.3
                                        showingEditLabel = true
                                    } label: {
                                        Label("Edit Label", systemImage: "pencil")
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 24)

                    Spacer()
                        .frame(height: 28)
                }
            }
        }
        .overlay {
            if showingShareOptions {
                ZStack {
                    Color(red: 27/255, green: 35/255, blue: 32/255)
                        .opacity(0.25)
                        .ignoresSafeArea()
                        .onTapGesture { showingShareOptions = false }

                    VStack(spacing: 0) {
                        Button {
                            showingShareOptions = false
                            didCopyOrShare = true
                            shareContent = ShareableContent(items: [selectedSubaddress])
                        } label: {
                            Text("Share Address")
                                .font(.system(size: 17, weight: .bold))
                                .foregroundStyle(Color.dsTextPrimary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 18)
                        }
                        .buttonStyle(.plain)

                        Divider()

                        Button {
                            showingShareOptions = false
                            didCopyOrShare = true
                            if let cgImage = try? qrDocument.cgImage(CGSize(width: 512, height: 512)) {
                                let uiImage = UIImage(cgImage: cgImage)
                                shareContent = ShareableContent(items: [uiImage], previewImage: uiImage)
                            }
                        } label: {
                            Text("Share QR Code")
                                .font(.system(size: 17, weight: .bold))
                                .foregroundStyle(Color.dsTextPrimary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 18)
                        }
                        .buttonStyle(.plain)
                    }
                    .frame(width: 260)
                    .background(Color.cream200)
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .shadow(color: .black.opacity(0.22), radius: 15, y: 12)
                }
            }
        }
        .sheet(item: $shareContent) { content in
            ActivityViewController(activityItems: content.items, previewImage: content.previewImage)
        }
        .overlay {
            if showingLabelInput {
                ZStack {
                    Color(red: 27/255, green: 35/255, blue: 32/255)
                        .opacity(0.25)
                        .ignoresSafeArea()
                        .onTapGesture {
                            showingLabelInput = false
                            newSubaddressLabel = ""
                        }

                    NewSubaddressLabelCard(
                        label: $newSubaddressLabel,
                        onCancel: {
                            showingLabelInput = false
                            newSubaddressLabel = ""
                        },
                        onCreate: {
                            generateSubaddress(label: newSubaddressLabel)
                            newSubaddressLabel = ""
                            showingLabelInput = false
                        }
                    )
                }
            }
        }
        .sheet(isPresented: $showingEditLabel) {
            EditSubaddressLabelSheet(label: $editLabelText) {
                if let index = editingSubaddressIndex {
                    walletManager.activeWallet?.setSubaddressLabel(addressIndex: index, label: editLabelText)
                }
                showingEditLabel = false
            }
            .presentationDetents([.height(200)])
        }
        .fullScreenCover(isPresented: $qrExpanded) {
            expandedQROverlay
        }
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
            }
        }
        .onChange(of: walletManager.activeWallet?.activeAccountIndex) { _ in
            newestSubaddressAddress = nil
            generateSubaddressIfNeeded()
            selectedSubaddress = walletManager.activeWallet?.activeSubaddresses.first?.0 ?? ""
        }
        .onAppear {
            generateSubaddressIfNeeded()
        }
        .onDisappear {
            if didCopyOrShare {
                ReviewManager.shared.requestReviewIfEligible()
            }
        }
    }

    // MARK: - Expanded QR overlay

    private var expandedQROverlay: some View {
        ZStack {
            Color(red: 27/255, green: 35/255, blue: 32/255)
                .opacity(0.85)
                .ignoresSafeArea()
                .onTapGesture { qrExpanded = false }

            VStack(spacing: 16) {
                if !activeAddressLabel.isEmpty {
                    Text(activeAddressLabel)
                        .font(.system(size: 13, weight: .bold))
                        .tracking(0.4)
                        .foregroundStyle(Color.white.opacity(0.9))
                }

                QRCodeDocumentUIView(document: qrDocument)
                    .frame(width: 300, height: 300)
                    .clipShape(RoundedRectangle(cornerRadius: 24))
                    .allowsHitTesting(false)

                HStack(spacing: 12) {
                    Button {
                        if let cgImage = try? qrDocument.cgImage(CGSize(width: 512, height: 512)) {
                            UIPasteboard.general.image = UIImage(cgImage: cgImage)
                            didCopyOrShare = true
                            withAnimation { qrImageCopied = true }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                                withAnimation { qrImageCopied = false }
                            }
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: qrImageCopied ? "checkmark" : "doc.on.doc")
                                .font(.system(size: 15))
                            Text(qrImageCopied ? "Copied" : "Copy")
                                .font(.system(size: 14, weight: .semibold))
                        }
                        .foregroundStyle(qrImageCopied ? Color.green : Color.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(Color.white.opacity(0.14))
                        .clipShape(Capsule())
                        .animation(.easeInOut(duration: 0.2), value: qrImageCopied)
                    }
                    .buttonStyle(.plain)

                    Button {
                        qrExpanded = false
                        didCopyOrShare = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                            if let cgImage = try? qrDocument.cgImage(CGSize(width: 512, height: 512)) {
                                let uiImage = UIImage(cgImage: cgImage)
                                shareContent = ShareableContent(items: [uiImage], previewImage: uiImage)
                            }
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "square.and.arrow.up")
                                .font(.system(size: 15))
                            Text("Share")
                                .font(.system(size: 14, weight: .semibold))
                        }
                        .foregroundStyle(Color.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(Color.white.opacity(0.14))
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }

                Text("Tap outside to close")
                    .font(.system(size: 13))
                    .foregroundStyle(Color.white.opacity(0.7))
            }
            .contentShape(Rectangle())
            .onTapGesture { }
        }
    }

    // MARK: - Account switcher pill

    private func accountSwitcherButton(_ activeWallet: XMRWallet) -> some View {
        let accountName = activeWallet.accountLabel(for: activeWallet.activeAccountIndex)
        let initial = String(accountName.trimmingCharacters(in: .whitespaces).prefix(1)).uppercased()

        return Button {
            showingAccountSheet = true
        } label: {
            HStack(spacing: 8) {
                Text(initial)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Color.dsAccentStrong)
                    .frame(width: 20, height: 20)
                    .background(Color.dsJadeSoft)
                    .clipShape(RoundedRectangle(cornerRadius: 6))

                Text(accountName)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.dsAccentStrong)

                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.dsAccentStrong)
            }
            .padding(.leading, 5)
            .padding(.trailing, 13)
            .padding(.vertical, 5)
            .overlay(
                Capsule().stroke(Color.dsJadeSoft, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Helpers

    private func generateSubaddress(label: String) {
        if let address = walletManager.activeWallet?.addNewSubaddress(label: label) {
            selectedSubaddress = address
            newestSubaddressAddress = address
        }
    }

    private func generateSubaddressIfNeeded() {
        guard let wallet = walletManager.activeWallet else { return }
        let subaddresses = wallet.activeSubaddresses
        if let lastSubaddress = subaddresses.first, lastSubaddress.2 > 0 {
            if let address = wallet.addNewSubaddress(label: "generated") {
                selectedSubaddress = address
            }
        }
    }
}

// MARK: - Subaddress Row

struct ReceiveSubaddressRow: View {
    let label: String
    let value: String
    let txCount: Int
    let highlighted: Bool
    let selected: Bool
    var onCopy: (() -> Void)? = nil

    @State private var copied = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 8) {
                // Radio circle
                ZStack {
                    Circle()
                        .strokeBorder(
                            selected ? Color.dsAccentStrong : Color.dsTextTertiary,
                            lineWidth: 1.5
                        )
                    if selected {
                        Circle().fill(Color.dsAccentStrong)
                        Image(systemName: "checkmark")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(Color.white)
                    }
                }
                .frame(width: 16, height: 16)
                .padding(.top, 2)

                VStack(alignment: .leading, spacing: 4) {
                    Text(label)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(highlighted ? Color.dsAccentStrong : Color.dsTextTertiary)
                        .kerning(0.5)

                    Text(value)
                        .font(.system(size: 12.5, weight: .regular, design: .monospaced))
                        .foregroundStyle(Color.dsTextPrimary)
                        .lineLimit(nil)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)

                // Copy button — only visible on the selected row
                if selected {
                    Button(action: copyValue) {
                        HStack(spacing: 4) {
                            Image(systemName: copied ? "checkmark" : "doc.on.doc")
                                .font(.system(size: 13))
                            Text(copied ? "Copied" : "Copy")
                                .font(.system(size: 13, weight: .semibold))
                        }
                        .foregroundStyle(copied ? Color.green : Color.dsAccentStrong)
                        .animation(.easeInOut(duration: 0.2), value: copied)
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 1)
                }
            }

            // Transaction count — indented to align under the address text
            Text("TRANSACTIONS: \(txCount)")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Color.dsTextTertiary)
                .kerning(0.4)
                .padding(.top, 8)
                .padding(.leading, 24)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(highlighted ? Color.dsJadeSoft : Color.dsSurface2)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(selected ? Color.dsAccentStrong : Color.clear, lineWidth: 1.5)
        )
    }

    private func copyValue() {
        UIPasteboard.general.string = value
        onCopy?()
        withAnimation { copied = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation { copied = false }
        }
    }
}

// MARK: - New Subaddress Label Card (centered overlay)

private struct NewSubaddressLabelCard: View {
    @Binding var label: String
    var onCancel: () -> Void
    var onCreate: () -> Void
    @FocusState private var isFocused: Bool

    private var trimmedLabel: String { label.trimmingCharacters(in: .whitespaces) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("New Subaddress")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(Color.dsTextPrimary)
                .frame(maxWidth: .infinity, alignment: .center)

            Text("Enter a label for the new subaddress.")
                .font(.system(size: 13))
                .foregroundStyle(Color.dsTextTertiary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.top, 12)

            TextField("", text: $label)
                .font(.system(size: 15))
                .focused($isFocused)
                .padding(.horizontal, 12)
                .frame(height: 42)
                .background(Color.dsSurface)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.dsBorder, lineWidth: 1)
                )
                .padding(.top, 10)
                .onChange(of: label) { _ in
                    if label.count > 24 { label = String(label.prefix(24)) }
                }

            Text("\(label.count)/24")
                .font(.system(size: 11))
                .foregroundStyle(Color.dsTextTertiary)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding(.top, 6)

            HStack(spacing: 10) {
                Button(action: onCancel) {
                    Text("Cancel")
                        .font(.system(size: 15, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .foregroundStyle(Color.dsAccentStrong)
                        .overlay(
                            RoundedRectangle(cornerRadius: 999)
                                .stroke(Color.dsBorder, lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)

                Button(action: onCreate) {
                    Group {
                        if trimmedLabel.isEmpty {
                            VStack(spacing: 1) {
                                Text("Create")
                                Text("without label")
                                    .font(.system(size: 11))
                            }
                        } else {
                            Text("Create")
                        }
                    }
                    .font(.system(size: 15, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .foregroundStyle(Color.dsTextOnAccent)
                    .background(Color.dsAccent)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
            .padding(.top, 18)
        }
        .padding(20)
        .frame(width: 300)
        .background(Color.dsSurface2)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: .black.opacity(0.22), radius: 15, y: 12)
        .onAppear { isFocused = true }
    }
}

// MARK: - Edit Subaddress Label Sheet

private struct EditSubaddressLabelSheet: View {
    @Binding var label: String
    var onSave: () -> Void
    @Environment(\.dismiss) private var dismiss
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(spacing: 16) {
            Text("Edit Label")
                .font(.headline)
                .padding(.top, 20)

            TextField("", text: $label)
                .textFieldStyle(.roundedBorder)
                .focused($isFocused)
                .onChange(of: label) { _ in
                    if label.count > 100 {
                        label = String(label.prefix(100))
                    }
                }
                .padding(.horizontal)

            HStack(spacing: 12) {
                Button("Cancel", role: .cancel) {
                    dismiss()
                }
                .buttonStyle(.bordered)

                Button("Save", action: onSave)
                    .buttonStyle(.borderedProminent)
            }
            .controlSize(.large)

            Spacer()
        }
        .onAppear {
            isFocused = true
        }
    }
}

// MARK: - Shareable Content

private struct ShareableContent: Identifiable {
    let id = UUID()
    let items: [Any]
    var previewImage: UIImage? = nil
}
