//
//  AWSelectCoin.swift
//  CapsizedVault
//

import SwiftUI

struct AWSelectCoin: View {

    @Binding var isPresented: Bool
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
            Text("New Wallet")
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
            ZStack {
                Circle()
                    .fill(Color.dsAccent.opacity(0.12))
                    .frame(width: 44, height: 44)
                Text(coin.ticker.prefix(1))
                    .font(.dsBodyLG)
                    .fontWeight(.bold)
                    .foregroundColor(.dsAccentStrong)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(coin.displayName)
                    .font(.dsBodyLG)
                    .foregroundColor(.dsTextPrimary)
                Text(coin.ticker)
                    .font(.dsBodySM)
                    .foregroundColor(.dsTextSecondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.dsTextTertiary)
        }
        .padding(.horizontal, 16)
        .frame(height: 72)
        .background(Color.dsSurfaceRaised)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

#Preview {
    AWSelectCoin(isPresented: .constant(true), onSelect: { _ in })
}
