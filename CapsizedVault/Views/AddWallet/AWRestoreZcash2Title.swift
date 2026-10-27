//
//  AWRestoreZcash2Title.swift
//  CapsizedVault
//

import SwiftUI

struct AWRestoreZcash2Title: View {

    let nextAction: () -> Void
    let backAction: () -> Void

    @State private var title: String = ""
    @State private var restoreHeight: String = ""
    @State private var restoreFromDate: Date = Date().addingYears(-1)
    @State private var useRestoreHeight: Bool = false
    @State private var useRestoreDate: Bool = false
    @State private var showError: Bool = false
    @State private var errorMessage: String = ""

    @FocusState private var isTitleFocused: Bool
    @FocusState private var isHeightFocused: Bool

    @EnvironmentObject var walletVM: AddWalletViewModel

    var body: some View {
        ZStack {
            Color.dsBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                headerView

                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {

                        Text("Wallet Title")
                            .font(.dsBodyMD)
                            .fontWeight(.semibold)
                            .foregroundColor(.dsTextSecondary)
                            .padding(.top, 8)

                        titleField
                            .padding(.top, 8)

                        Text("Birthday")
                            .font(.dsBodyMD)
                            .fontWeight(.semibold)
                            .foregroundColor(.dsTextSecondary)
                            .padding(.top, 24)

                        birthdayCard
                            .padding(.top, 8)

                        if !useRestoreHeight && !useRestoreDate {
                            Text("Without a birthday, the wallet scans from Oct 2018 — this can take a long time.")
                                .font(.dsBodySM)
                                .foregroundColor(.dsTextTertiary)
                                .padding(.top, 8)
                        }

                        Spacer(minLength: 32)

                        VStack(spacing: 12) {
                            Button {
                                handleRestore()
                            } label: {
                                Text("Restore")
                            }
                            .buttonStyle(.dsPrimary)
                            .disabled(!isFormValid)
                            .opacity(isFormValid ? 1 : 0.5)

                            Button {
                                saveStateForBack()
                                backAction()
                            } label: {
                                Text("Back")
                                    .font(.dsButtonLG)
                                    .foregroundColor(.dsAccent)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 56)
                                    .background(Color.dsSurfaceRaised)
                                    .clipShape(Capsule())
                            }
                        }
                        .padding(.top, 24)
                        .padding(.bottom, 32)
                    }
                    .padding(.horizontal, 24)
                    .instantScrollViewTouches()
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            if isHeightFocused || isTitleFocused {
                HStack {
                    Spacer()
                    Button("Done") {
                        isHeightFocused = false
                        isTitleFocused = false
                    }
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundColor(.dsAccentStrong)
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(Color.dsSurface)
                .overlay(alignment: .top) {
                    Rectangle()
                        .fill(Color.dsBorder)
                        .frame(height: 0.5)
                }
            }
        }
        .onAppear {
            let data = walletVM.restoreZcashWalletData
            if let savedTitle = data.title {
                title = savedTitle
            }
            if let savedHeight = data.birthdayHeight {
                useRestoreHeight = true
                useRestoreDate = false
                restoreHeight = "\(savedHeight)"
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                isTitleFocused = true
            }
        }
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
    }

    // MARK: - Save state helper

    private func saveStateForBack() {
        walletVM.restoreZcashWalletData.title = trimmedTitle.isEmpty ? nil : trimmedTitle
        if useRestoreHeight {
            walletVM.restoreZcashWalletData.birthdayHeight = Int(restoreHeight)
        } else if useRestoreDate {
            walletVM.restoreZcashWalletData.birthdayHeight = ZcashBirthday.height(for: restoreFromDate)
        } else {
            walletVM.restoreZcashWalletData.birthdayHeight = nil
        }
    }

    // MARK: - Header

    private var headerView: some View {
        ZStack {
            Text("Restore Wallet")
                .font(.dsHeadingLG)
                .foregroundColor(.dsTextPrimary)

            HStack {
                Button {
                    saveStateForBack()
                    backAction()
                } label: {
                    ZStack {
                        Circle()
                            .fill(Color.dsTextPrimary.opacity(0.08))
                            .frame(width: 36, height: 36)
                        Image(systemName: "chevron.left")
                            .font(.system(size: 14, weight: .semibold))
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
        TextField("Title", text: $title)
            .font(.dsBodyLG)
            .foregroundColor(.dsTextPrimary)
            .textContentType(.oneTimeCode)
            .autocorrectionDisabled()
            .focused($isTitleFocused)
            .padding(.horizontal, 16)
            .frame(height: 54)
            .background(Color.dsSurfaceRaised)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isTitleFocused ? Color.dsAccent : Color.dsBorder, lineWidth: isTitleFocused ? 1.5 : 1)
            )
    }

    // MARK: - Birthday Card

    private var birthdayCard: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Use Block Height")
                    .font(.dsBodyLG)
                    .foregroundColor(.dsTextPrimary)
                Spacer()
                Toggle("", isOn: $useRestoreHeight)
                    .tint(.dsAccent)
                    .labelsHidden()
                    .onChange(of: useRestoreHeight) { newValue in
                        if newValue {
                            useRestoreDate = false
                        }
                    }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)

            Rectangle()
                .fill(Color.dsBorder)
                .frame(height: 0.5)

            TextField("Block Height", text: $restoreHeight)
                .keyboardType(.numberPad)
                .focused($isHeightFocused)
                .disabled(!useRestoreHeight)
                .foregroundColor(useRestoreHeight ? .dsTextPrimary : .dsTextTertiary)
                .font(.dsBodyLG)
                .padding(.horizontal, 16)
                .frame(height: 48)

            Rectangle()
                .fill(Color.dsBorder)
                .frame(height: 0.5)

            HStack {
                Text("Use Date")
                    .font(.dsBodyLG)
                    .foregroundColor(.dsTextPrimary)
                Spacer()
                Toggle("", isOn: $useRestoreDate)
                    .tint(.dsAccent)
                    .labelsHidden()
                    .onChange(of: useRestoreDate) { newValue in
                        if newValue {
                            useRestoreHeight = false
                            restoreHeight = "\(ZcashBirthday.height(for: restoreFromDate))"
                        }
                    }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)

            if useRestoreDate {
                Rectangle()
                    .fill(Color.dsBorder)
                    .frame(height: 0.5)

                HStack {
                    Text("Restore From Date")
                        .font(.dsBodyLG)
                        .foregroundColor(.dsTextPrimary)
                    Spacer()
                    DatePicker("", selection: $restoreFromDate, displayedComponents: .date)
                        .labelsHidden()
                        .tint(.dsAccent)
                        .onChange(of: restoreFromDate) { newDate in
                            restoreHeight = "\(ZcashBirthday.height(for: newDate))"
                        }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
            }
        }
        .background(Color.dsSurfaceRaised)
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    // MARK: - Validation & Helpers

    private var trimmedTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var isFormValid: Bool {
        guard !trimmedTitle.isEmpty else { return false }
        if useRestoreHeight {
            return Int(restoreHeight) != nil && !restoreHeight.isEmpty
        }
        return true
    }

    private func handleRestore() {
        guard !trimmedTitle.isEmpty else {
            errorMessage = "Title is required"
            showError = true
            return
        }

        if useRestoreHeight {
            guard !restoreHeight.isEmpty, Int(restoreHeight) != nil else {
                errorMessage = "Block height must be a valid number"
                showError = true
                return
            }
        }

        walletVM.restoreZcashWalletData.title = trimmedTitle
        if useRestoreHeight {
            walletVM.restoreZcashWalletData.birthdayHeight = Int(restoreHeight)
        } else if useRestoreDate {
            walletVM.restoreZcashWalletData.birthdayHeight = ZcashBirthday.height(for: restoreFromDate)
        } else {
            walletVM.restoreZcashWalletData.birthdayHeight = nil
        }

        nextAction()
    }
}
