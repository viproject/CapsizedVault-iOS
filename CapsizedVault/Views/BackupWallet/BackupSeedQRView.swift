//
//  BackupSeedQRView.swift
//  CapsizedVault
//
//  Created by Dmitrij on 23/05/2026.
//

import SwiftUI
import QRCode

struct BackupSeedQRView: View {

    let words: [String]
    let restoreHeight: UInt64?

    @State private var shareImage: ShareableImage?

    private var qrString: String {
        let seed = words.joined(separator: "+")
        var result = "monero-wallet:?seed=\(seed)"
        if let height = restoreHeight {
            result += "&height=\(height)"
        }
        return result
    }

    private var qrDocument: QRCode.Document {
        let doc = try! QRCode.Document(utf8String: qrString)
        doc.errorCorrection = .medium
        doc.design.foregroundColor(CGColor(srgbRed: 0, green: 0, blue: 0, alpha: 1.0))
        doc.design.backgroundColor(CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 1.0))
        doc.design.shape.onPixels = QRCode.PixelShape.RoundedPath(cornerRadiusFraction: 0.7, hasInnerCorners: true)
        doc.design.shape.eye = QRCode.EyeShape.RoundedRect()
        return doc
    }

    var body: some View {
        VStack(spacing: 16) {
            ZStack {
                Text("Seed QR Code")
                    .font(.headline)
                    .frame(maxWidth: .infinity, alignment: .center)

                HStack {
                    Spacer()
                    Button {
                        if let image = try? qrDocument.cgImage(CGSize(width: 512, height: 512)) {
                            shareImage = ShareableImage(image: UIImage(cgImage: image))
                        }
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 18))
                    }
                    .padding(.trailing, 16)
                }
            }

            QRCodeDocumentUIView(document: qrDocument)
                .frame(width: 250, height: 250)

            Text("Scan this QR code to restore your wallet.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .padding()
        .sheet(item: $shareImage) { item in
            ActivityViewController(activityItems: [item.image])
        }
    }
}

private struct ShareableImage: Identifiable {
    let id = UUID()
    let image: UIImage
}
