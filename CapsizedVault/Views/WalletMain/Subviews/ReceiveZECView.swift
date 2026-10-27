//
//  ReceiveZECView.swift
//  CapsizedVault
//

import SwiftUI
import QRCode

private enum ZECReceiveAddressType: String, CaseIterable {
    case unified = "Unified"
    case transparent = "Transparent"
}

struct ReceiveZECView: View {

    @StateObject private var walletManager = WalletManager.shared
    @State private var addressType: ZECReceiveAddressType = .unified
    @State private var showingShareOptions = false
    @State private var shareContent: ZECShareableContent?
    @State private var qrExpanded = false
    @State private var qrImageCopied = false
    @State private var didCopyOrShare = false
    @State private var isShielding = false
    @State private var shieldResultMessage: String?

    private var wallet: ZECWallet? { walletManager.activeWallet?.zcashWallet }

    private var currentAddress: String {
        switch addressType {
        case .unified: return wallet?.unifiedAddress ?? ""
        case .transparent: return wallet?.transparentAddress ?? ""
        }
    }

    private var transparentBalance: CoinAmount? {
        wallet?.accounts.first?.transparent
    }

    private var canShield: Bool {
        wallet?.capabilities.supportsShielding == true && (transparentBalance?.isZero == false)
    }

    private var qrDocument: QRCode.Document {
        let doc = try! QRCode.Document(utf8String: currentAddress)
        doc.errorCorrection = .medium
        doc.design.foregroundColor(CGColor(red: 0.420, green: 0.478, blue: 0.165, alpha: 1.0))
        doc.design.backgroundColor(CGColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0))
        doc.design.shape.onPixels = QRCode.PixelShape.RoundedPath(cornerRadiusFraction: 0.7, hasInnerCorners: true)
        doc.design.shape.eye = QRCode.EyeShape.RoundedRect()
        return doc
    }

    var body: some View {
        VStack(spacing: 0) {
            // MARK: - Header (fixed, not scrolling)
            ZStack {
                Text("Receive ZEC")
                    .font(.system(size: 19, weight: .bold))
                    .foregroundStyle(Color.dsTextPrimary)
                    .frame(maxWidth: .infinity, alignment: .center)

                HStack {
                    Spacer()
                    if !currentAddress.isEmpty {
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
                    VStack(spacing: 10) {
                        Button {
                            qrExpanded = true
                        } label: {
                            QRCodeDocumentUIView(document: qrDocument)
                                .frame(width: 200, height: 200)
                                .clipShape(RoundedRectangle(cornerRadius: 20))
                        }
                        .buttonStyle(.plain)
                        .disabled(currentAddress.isEmpty)

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
                        .opacity(currentAddress.isEmpty ? 0 : 1)
                    }
                    .padding(.top, 24)

                    Divider()
                        .padding(.top, 20)

                    Picker("Address type", selection: $addressType) {
                        ForEach(ZECReceiveAddressType.allCases, id: \.self) { type in
                            Text(type.rawValue).tag(type)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, 20)
                    .padding(.top, 20)

                    ZECReceiveAddressRow(value: currentAddress, onCopy: { didCopyOrShare = true })
                        .padding(.horizontal, 20)
                        .padding(.top, 16)

                    if addressType == .transparent {
                        Text("Transparent addresses are visible on the public blockchain. Shield received funds to move them into your private balance.")
                            .font(.system(size: 12))
                            .foregroundStyle(Color(red: 0.698, green: 0.561, blue: 0.251))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 20)
                            .padding(.top, 12)
                    }

                    if canShield {
                        shieldFundsCard
                            .padding(.horizontal, 20)
                            .padding(.top, 20)
                    }

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
                            shareContent = ZECShareableContent(items: [currentAddress])
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
                                shareContent = ZECShareableContent(items: [uiImage], previewImage: uiImage)
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
        .fullScreenCover(isPresented: $qrExpanded) {
            expandedQROverlay
        }
        .alert("Shield funds", isPresented: Binding(
            get: { shieldResultMessage != nil },
            set: { if !$0 { shieldResultMessage = nil } }
        )) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(shieldResultMessage ?? "")
        }
        .onDisappear {
            if didCopyOrShare {
                ReviewManager.shared.requestReviewIfEligible()
            }
        }
    }

    // MARK: - Shield funds card

    private var shieldFundsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Transparent balance")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.dsTextTertiary)
                Spacer()
                Text("\(transparentBalance?.formatted(style: .balance) ?? "0") ZEC")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.dsTextPrimary)
            }

            Button {
                shieldFunds()
            } label: {
                HStack(spacing: 8) {
                    if isShielding {
                        ProgressView()
                            .tint(Color.dsTextOnAccent)
                    }
                    Text(isShielding ? "Shielding…" : "Shield Funds")
                        .font(.system(size: 15, weight: .semibold))
                }
                .foregroundStyle(Color.dsTextOnAccent)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color.dsAccent)
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .disabled(isShielding)
        }
        .padding(16)
        .background(Color.dsSurface2)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func shieldFunds() {
        guard let wallet else { return }
        isShielding = true
        Task {
            let result = await wallet.shieldFunds()
            isShielding = false
            switch result {
            case .success(let shielded):
                shieldResultMessage = shielded
                    ? "Your transparent balance is being shielded."
                    : "There was no transparent balance to shield."
            case .failure(let error):
                shieldResultMessage = error.userMessage
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
                Text(addressType.rawValue.uppercased())
                    .font(.system(size: 13, weight: .bold))
                    .tracking(0.4)
                    .foregroundStyle(Color.white.opacity(0.9))

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
                                shareContent = ZECShareableContent(items: [uiImage], previewImage: uiImage)
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
}

// MARK: - Address row

private struct ZECReceiveAddressRow: View {
    let value: String
    var onCopy: (() -> Void)? = nil

    @State private var copied = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(value)
                .font(.system(size: 12.5, weight: .regular, design: .monospaced))
                .foregroundStyle(Color.dsTextPrimary)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)

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
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Color.dsSurface2)
        .clipShape(RoundedRectangle(cornerRadius: 16))
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

// MARK: - Shareable Content

private struct ZECShareableContent: Identifiable {
    let id = UUID()
    let items: [Any]
    var previewImage: UIImage? = nil
}
