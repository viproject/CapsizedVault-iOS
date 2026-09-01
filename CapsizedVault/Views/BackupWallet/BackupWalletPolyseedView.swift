//
//  BackupWalletPolyseedView.swift
//  CapsizedVault
//
//  Created by Dmitrij on 03/03/2026.
//

import SwiftUI

struct BackupWalletPolyseedView: View {

    let words: [String]
    var onBackedUp: (() -> Void)? = nil
    
    let columns = [
        GridItem(.flexible()),
        GridItem(.flexible())
    ]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Spacer()
                Button(action: copyToClipboard) {
                    HStack(spacing: 4) {
                        Image(systemName: "doc.on.doc")
                            .font(.system(size: 14))
                        Text("Copy")
                            .font(.system(size: 15))
                    }
                }
            }
            .padding(.bottom, 12)
            
            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(Array(words.enumerated()), id: \.offset) { index, word in
                    WordCell(index: index + 1, word: word)
                }
            }
        }
        .padding()
    }
    
    func copyToClipboard() {
        let joined = words
            .joined(separator: " ")
        UIPasteboard.general.string = joined
        onBackedUp?()
    }
}

struct WordCell: View {
    let index: Int
    let word: String
    
    var body: some View {
        HStack(spacing: 8) {
            Text("\(index)")
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundStyle(.secondary)
                .frame(width: 22, alignment: .trailing)
            
            Text(word)
                .font(.system(size: 15, weight: .medium, design: .monospaced))
                .foregroundStyle(.primary)
            
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}
