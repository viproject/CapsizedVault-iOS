//
//  QRCode+CoinLogo.swift
//  CapsizedVault
//

import UIKit
import QRCode

extension QRCode.Document {
    /// Centers the coin's logo in the QR code. Raises error correction to `.high`
    /// so the code still scans with the center modules covered by the logo.
    func applyLogo(for coin: Coin) {
        guard let logo = UIImage(named: coin.logoAssetName) else { return }
        // Render the vector asset at a fixed size; the CGImage backing an SVG asset
        // can be nil or tiny depending on how it was last rasterized.
        let size = CGSize(width: 256, height: 256)
        let rendered = UIGraphicsImageRenderer(size: size).image { _ in
            logo.draw(in: CGRect(origin: .zero, size: size))
        }
        guard let cgImage = rendered.cgImage else { return }
        errorCorrection = .high
        logoTemplate = QRCode.LogoTemplate.CircleCenter(image: cgImage, inset: 4)
    }
}
