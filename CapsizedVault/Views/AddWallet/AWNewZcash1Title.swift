//
//  AWNewZcash1Title.swift
//  CapsizedVault
//

import SwiftUI

struct AWNewZcash1Title: View {

    @Binding var isPresented: Bool
    let nextAction: () -> Void

    @State private var walletTitle: String = ""
    @FocusState private var titleFieldFocused: Bool

    @EnvironmentObject var walletVM: AddWalletViewModel

    var body: some View {
        ZStack {
            Color.dsBackground
                .ignoresSafeArea()

            VStack(spacing: 0) {
                headerView

                ScrollView {
                    VStack(spacing: 0) {
                        titleField
                            .padding(.top, 24)

                        Spacer(minLength: 32)

                        createWalletButton
                            .padding(.top, 24)
                            .padding(.bottom, 32)
                    }
                    .padding(.horizontal, 24)
                    .instantScrollViewTouches()
                }
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

    // MARK: - Title Field

    private var titleField: some View {
        TextField("Enter title …", text: $walletTitle)
            .font(.dsBodyLG)
            .foregroundColor(.dsTextPrimary)
            .autocorrectionDisabled()
            .textInputAutocapitalization(.words)
            .focused($titleFieldFocused)
            .padding(.horizontal, 16)
            .frame(height: 54)
            .background(Color.dsSurfaceRaised)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.dsAccent, lineWidth: 1.5)
            )
            .onAppear { titleFieldFocused = true }
    }

    // MARK: - Create Wallet Button

    private var isTitleValid: Bool {
        !walletTitle.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private var createWalletButton: some View {
        Button {
            walletVM.newZcashWalletData.title = walletTitle.trimmingCharacters(in: .whitespaces)
            nextAction()
        } label: {
            Text("Create Wallet")
                .font(.dsButtonLG)
                .foregroundColor(isTitleValid ? .white : .dsTextTertiary)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(isTitleValid ? Color.dsAccent : Color.dsSurfaceSunken)
                .clipShape(RoundedRectangle(cornerRadius: 18))
                .shadow(color: isTitleValid ? Color.dsAccent.opacity(0.35) : .clear, radius: 12, x: 0, y: 6)
        }
        .disabled(!isTitleValid)
    }
}

#Preview {
    AWNewZcash1Title(isPresented: .constant(true), nextAction: {})
        .environmentObject(AddWalletViewModel())
}
