//
//  AWSelectCoin.swift
//  CapsizedVault
//

import SwiftUI

struct AWSelectCoin: View {

    @Binding var isPresented: Bool
    var title: String = "New Wallet"
    let onSelect: (Coin) -> Void

    var body: some View {
        ZStack {
            Color.dsBackground
                .ignoresSafeArea()

            VStack(spacing: 0) {
                headerView

                VStack(spacing: 12) {
                    ForEach(Coin.allCases, id: \.self) { coin in
                        Button {
                            onSelect(coin)
                        } label: {
                            coinRow(coin)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 24)

                Spacer()
            }
        }
    }

    // MARK: - Header

    private var headerView: some View {
        ZStack {
            Text(title)
                .font(.dsHeadingLG)
                .foregroundColor(.dsTextPrimary)

            HStack {
                Button {
                    isPresented = false
                } label: {
                    ZStack {
                        Circle()
                            .fill(Color.dsTextPrimary.opacity(0.08))
                            .frame(width: 36, height: 36)
                        Image(systemName: "xmark")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.dsTextPrimary)
                    }
                }
                .buttonStyle(.plain)
                Spacer()
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 16)
        .padding(.bottom, 12)
    }

    // MARK: - Coin Row

    private func coinRow(_ coin: Coin) -> some View {
        HStack(spacing: 14) {
            Image(coin.logoAssetName)
                .resizable()
                .scaledToFit()
                .frame(width: 48, height: 48)

            VStack(alignment: .leading, spacing: 2) {
                Text("\(coin.displayName) · \(coin.ticker)")
                    .font(.dsBodyLG)
                    .foregroundColor(.dsTextPrimary)
                Text(tagline(coin))
                    .font(.dsBodySM)
                    .foregroundColor(.dsTextSecondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.dsTextTertiary)
        }
        .padding(.horizontal, 16)
        .frame(height: 84)
        .background(Color.dsSurfaceRaised)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func tagline(_ coin: Coin) -> String {
        switch coin {
        case .monero: return "Private by default"
        case .zcash: return "Shielded transactions"
        }
    }
}

#Preview {
    AWSelectCoin(isPresented: .constant(true), onSelect: { _ in })
}
