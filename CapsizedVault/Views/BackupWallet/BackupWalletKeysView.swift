//
//  BackupWalletKeysView.swift
//  CapsizedVault
//
//  Created by Dmitrij on 03/03/2026.
//

import SwiftUI

struct BackupWalletKeysView: View {
    
    let primaryAddress: String
    let spendKeyPublic: String
    let spendKeyPrivate: String
    let viewKeyPublic: String
    let viewKeyPrivate: String
    var onBackedUp: (() -> Void)? = nil

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                KeyFieldRow(label: "Primary Address",   value: primaryAddress,  isAddress: true, onCopied: onBackedUp)
                KeyFieldRow(label: "Spend Key (public)",  value: spendKeyPublic, onCopied: onBackedUp)
                KeyFieldRow(label: "Spend Key (private)", value: spendKeyPrivate, isSensitive: true, onCopied: onBackedUp)
                KeyFieldRow(label: "View Key (public)",   value: viewKeyPublic, onCopied: onBackedUp)
                KeyFieldRow(label: "View Key (private)",  value: viewKeyPrivate,  isSensitive: true, onCopied: onBackedUp)
            }
            .padding()
        }
    }
}

struct KeyFieldRow: View {
    let label: String
    let value: String
    var isAddress: Bool  = false
    var isSensitive: Bool = false
    var onCopied: (() -> Void)? = nil

    @State private var copied = false
    @State private var isRevealed = false

    private var displayValue: String {
        guard isSensitive && !isRevealed else { return value }
        return String(repeating: "•", count: 16)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // — Label row
            HStack {
                if isSensitive {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(.orange)
                }
                Text(label)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                    .kerning(0.4)
            }

            // — Value + actions
            HStack(alignment: .top, spacing: 8) {
                Text(displayValue)
                    .font(.system(size: isAddress ? 13 : 14,
                                  weight: .regular,
                                  design: .monospaced))
                    .foregroundStyle(.primary)
                    .lineLimit(isAddress ? 3 : 2)
                    .truncationMode(.middle)
                    .frame(maxWidth: .infinity, alignment: .leading)

                HStack(spacing: 6) {
                    // Reveal / hide for private keys
                    if isSensitive {
                        Button(action: { withAnimation { isRevealed.toggle() } }) {
                            Image(systemName: isRevealed ? "eye.slash" : "eye")
                                .font(.system(size: 14))
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }

                    // Copy button
                    Button(action: copyValue) {
                        HStack(spacing: 3) {
                            Image(systemName: copied ? "checkmark" : "doc.on.doc")
                                .font(.system(size: 13))
                            Text(copied ? "Copied" : "Copy")
                                .font(.system(size: 13, weight: .medium))
                        }
                        .foregroundStyle(copied ? .green : .accentColor)
                        .animation(.easeInOut(duration: 0.2), value: copied)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.top, 1)
            }
        }
        .padding(12)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func copyValue() {
        UIPasteboard.general.string = value
        withAnimation { copied = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation { copied = false }
        }
        onCopied?()
    }
}
