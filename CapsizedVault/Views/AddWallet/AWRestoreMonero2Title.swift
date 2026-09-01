//
//  AWRestoreMonero2Title.swift
//  CapsizedVault
//
//  Created by Dmitrij on 28/01/2026.
//

import SwiftUI
import CapsizedMoneroKit


struct AWRestoreMonero2Title: View {
    
    let nextAction: () -> Void
    let backAction: () -> Void
    
    @State private var title: String = ""
    @State private var restoreHeight: String = ""
    @State private var restoreFromDate: Date = Date().addingYears(-1)
    @State private var passphrase: String = ""
    @State private var isPassphraseVisible: Bool = false
    @State private var useRestoreHeight: Bool = true
    @State private var useRestoreDate: Bool = false
    @State private var showError: Bool = false
    @State private var errorMessage: String = ""

    @FocusState private var isTitleFocused: Bool
    @FocusState private var isHeightFocused: Bool
    @FocusState private var isPassphraseFocused: Bool

    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var walletVM: AddWalletViewModel

    var body: some View {
        ZStack {
            Color.dsBackground.ignoresSafeArea()
            
            VStack(spacing: 0) {
                headerView
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        
                        // Wallet Title
                        Text("Wallet Title")
                            .font(.dsBodyMD)
                            .fontWeight(.semibold)
                            .foregroundColor(.dsTextSecondary)
                            .padding(.top, 8)
                        
                        titleField
                            .padding(.top, 8)
                        
                        // Restore Options
                        if walletVM.restoreMoneroWalletData.canUseRestoreOptions() {
                            Text("Restore Options")
                                .font(.dsBodyMD)
                                .fontWeight(.semibold)
                                .foregroundColor(.dsTextSecondary)
                                .padding(.top, 24)
                            
                            restoreOptionsCard
                                .padding(.top, 8)
                        }
                        
                        // Passphrase (seed restores only)
                        if walletVM.restoreMoneroWalletData.isFromSeed {
                            HStack(alignment: .firstTextBaseline, spacing: 6) {
                                Text("Passphrase")
                                    .font(.dsBodyMD)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.dsTextSecondary)
                                Text("Optional")
                                    .font(.dsBodySM)
                                    .foregroundColor(.dsTextTertiary)
                            }
                            .padding(.top, 24)
                            
                            passphraseField
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
            if isHeightFocused || isTitleFocused || isPassphraseFocused {
                HStack {
                    Spacer()
                    Button("Done") {
                        isHeightFocused = false
                        isTitleFocused = false
                        isPassphraseFocused = false
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
            let data = walletVM.restoreMoneroWalletData
            if let savedTitle = data.title {
                title = savedTitle
            }
            if let savedDate = data.restoreDate {
                useRestoreDate = true
                useRestoreHeight = false
                restoreFromDate = savedDate
            } else if data.restoreHeight > 0 {
                useRestoreHeight = true
                useRestoreDate = false
                restoreHeight = "\(data.restoreHeight)"
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
        walletVM.restoreMoneroWalletData.title = trimmedTitle.isEmpty ? nil : trimmedTitle
        if useRestoreDate {
            walletVM.restoreMoneroWalletData.restoreDate = restoreFromDate
            walletVM.restoreMoneroWalletData.restoreHeight = 0
        } else if useRestoreHeight {
            walletVM.restoreMoneroWalletData.restoreHeight = Int(restoreHeight) ?? 0
            walletVM.restoreMoneroWalletData.restoreDate = nil
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
    
    // MARK: - Restore Options Card

    private var restoreOptionsCard: some View {
        VStack(spacing: 0) {
            // Use Restore Height toggle
            HStack {
                Text("Use Restore Height")
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

            // Restore Height field
            TextField("Restore Height", text: $restoreHeight)
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

            // Use Restore From Date toggle
            HStack {
                Text("Use Restore From Date")
                    .font(.dsBodyLG)
                    .foregroundColor(.dsTextPrimary)
                Spacer()
                Toggle("", isOn: $useRestoreDate)
                    .tint(.dsAccent)
                    .labelsHidden()
                    .onChange(of: useRestoreDate) { newValue in
                        if newValue {
                            useRestoreHeight = false
                            restoreHeight = "\(RestoreHeight.getHeight(date: restoreFromDate))"
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
                            restoreHeight = "\(RestoreHeight.getHeight(date: newDate))"
                        }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
            }
        }
        .background(Color.dsSurfaceRaised)
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }
    
    // MARK: - Passphrase Field

    private var passphraseField: some View {
        HStack {
            Group {
                if isPassphraseVisible {
                    TextField("Passphrase", text: $passphrase)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                } else {
                    SecureField("Passphrase", text: $passphrase)
                        .textContentType(.oneTimeCode)
                }
            }
            .font(.dsBodyLG)
            .foregroundColor(.dsTextPrimary)
            .focused($isPassphraseFocused)

            Button {
                isPassphraseVisible.toggle()
            } label: {
                Image(systemName: isPassphraseVisible ? "eye" : "eye.slash")
                    .foregroundColor(.dsAccentStrong)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .frame(height: 54)
        .background(Color.dsSurfaceRaised)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(isPassphraseFocused ? Color.dsAccent : Color.dsBorder, lineWidth: isPassphraseFocused ? 1.5 : 1)
        )
    }
    
    // MARK: - Validation & Helpers
    
    private var trimmedTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var isFormValid: Bool {
        guard !trimmedTitle.isEmpty else { return false }
        if walletVM.restoreMoneroWalletData.canUseRestoreOptions() {
            if useRestoreHeight {
                return Int(restoreHeight) != nil && !restoreHeight.isEmpty
            }
            return useRestoreDate
        }
        return true
    }

    private func handleRestore() {
        guard !trimmedTitle.isEmpty else {
            errorMessage = "Title is required"
            showError = true
            return
        }

        if walletVM.restoreMoneroWalletData.canUseRestoreOptions() && !useRestoreHeight && !useRestoreDate {
            errorMessage = "Restore height or restore date is required"
            showError = true
            return
        }

        if walletVM.restoreMoneroWalletData.canUseRestoreOptions() && useRestoreHeight {
            guard !restoreHeight.isEmpty, Int(restoreHeight) != nil else {
                errorMessage = "Restore height must be a valid number"
                showError = true
                return
            }
        }
        
        walletVM.restoreMoneroWalletData.title = trimmedTitle
        if useRestoreHeight && !restoreHeight.isEmpty {
            walletVM.restoreMoneroWalletData.restoreHeight = Int(restoreHeight) ?? 0
            walletVM.restoreMoneroWalletData.restoreDate = nil
        }
        if useRestoreDate {
            walletVM.restoreMoneroWalletData.restoreDate = restoreFromDate
            walletVM.restoreMoneroWalletData.restoreHeight = 0
        }
        if !passphrase.isEmpty {
            walletVM.restoreMoneroWalletData.passphrase = passphrase
        }
        
        nextAction()
    }
}
