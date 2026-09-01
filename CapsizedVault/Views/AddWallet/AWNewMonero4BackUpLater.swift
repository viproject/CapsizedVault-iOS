//
//  AWNewMonero4BackUpLater.swift
//  CapsizedVault
//
//  Created by Dmitrij on 14/01/2026.
//

import SwiftUI

struct AWNewMonero4BackUpLater: View {

    let nextAction: () -> Void
    let backAction: () -> Void

    var body: some View {
        ZStack {
            Color.dsBackground
                .ignoresSafeArea()

            VStack(spacing: 0) {

                // Title
                Text("Back Up Your Seed Phrase")
                    .font(.dsHeadingLG)
                    .foregroundColor(.dsTextPrimary)
                    .multilineTextAlignment(.center)
                    .padding(.top, 40)

                // Warning icon
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 40))
                    .foregroundColor(.dsDanger)
                    .padding(.top, 40)

                // Headline
                Text("Your seed phrase has not been backed up yet.")
                    .font(.dsHeadingMD)
                    .foregroundColor(.dsTextPrimary)
                    .multilineTextAlignment(.center)
                    .padding(.top, 24)

                // Body
                Text("Without a backup, you will permanently lose access to your funds if you lose, replace, or reset your device. There is no other way to recover your wallet.")
                    .font(.dsBodyMD)
                    .foregroundColor(.dsTextSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .padding(.top, 14)

                Spacer()

                // Buttons
                VStack(spacing: 20) {
                    Button {
                        backAction()
                    } label: {
                        Text("Back Up Now")
                    }
                    .buttonStyle(.dsPrimary)

                    Button {
                        nextAction()
                    } label: {
                        Text("I'll Do It Later")
                            .font(.dsButtonLG)
                            .foregroundColor(.dsAccent)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(Color.dsSurfaceRaised)
                            .clipShape(Capsule())
                    }
                }
                .padding(.top, 28)

                // Footer note
                Text("You can back up your seed phrase anytime from wallet settings.")
                    .font(.dsBodySM)
                    .foregroundColor(.dsTextTertiary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
                    .padding(.top, 12)
                    .padding(.bottom, 40)
            }
            .padding(.horizontal, 24)
        }
    }
}
