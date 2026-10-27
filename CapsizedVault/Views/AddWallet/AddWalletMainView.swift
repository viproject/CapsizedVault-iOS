//
//  AddNewWalletMainView.swift
//  CapsizedVault
//
//  Created by Dmitrij on 19/12/2025.
//

import SwiftUI
import CapsizedMoneroKit
import HsToolKit
import HdWalletKit

enum AWCurrentView {
    case selectCoin
    case newMonero1Title, newMonero3SeedBackUp, newMonero4BackUpLater
    case newZcash1Title, newZcash2SeedBackUp, newZcash3BackUpLater
    case restoreMonero1SeedKeys, restoreMonero2Title
    case restoreZcash1SeedKeys, restoreZcash2Title
}

enum AWWalletType {
    case moneroNew, moneroRestore, zcashNew, zcashRestore
}

struct AddWalletMainView: View {


    @Binding var isPresented: Bool

    @State private var currentWalletType: AWWalletType
    @State private var currentView: AWCurrentView
    @State private var restoreError: String?
    @StateObject private var walletVM = AddWalletViewModel()

    /// Whether this sheet was opened for Restore rather than Create — set once from the
    /// `currentWalletType` passed in from `WalletMainView`/`OnboardingView`/`WalletSwitchSheet`,
    /// all of which still only distinguish "new" vs "restore" at that call site (the coin
    /// choice happens after this sheet opens, via `AWSelectCoin`).
    private let isRestoreFlow: Bool

    let daemonAddress: String = "http://xmr-node.cakewallet.com:18081"
    let restoreHeight: String = "\(RestoreHeight.getHeight(date: Date()))"

    init(isPresented: Binding<Bool>, currentWalletType: AWWalletType) {
        self._isPresented = isPresented
        self._currentWalletType = State(initialValue: currentWalletType)
        self.isRestoreFlow = currentWalletType == .moneroRestore

        switch currentWalletType {
        case .moneroNew, .moneroRestore:
            _currentView = State(initialValue: .selectCoin)
        case .zcashNew:
            _currentView = State(initialValue: .newZcash1Title)
        case .zcashRestore:
            _currentView = State(initialValue: .selectCoin)
        }
    }


    var body: some View {
        Group {
            switch currentView {
            case .selectCoin:
                AWSelectCoin(isPresented: $isPresented, title: isRestoreFlow ? "Restore Wallet" : "New Wallet") { coin in
                    if isRestoreFlow {
                        switch coin {
                        case .monero:
                            currentWalletType = .moneroRestore
                            currentView = .restoreMonero1SeedKeys
                        case .zcash:
                            currentWalletType = .zcashRestore
                            currentView = .restoreZcash1SeedKeys
                        }
                    } else {
                        switch coin {
                        case .monero:
                            currentWalletType = .moneroNew
                            currentView = .newMonero1Title
                        case .zcash:
                            currentWalletType = .zcashNew
                            currentView = .newZcash1Title
                        }
                    }
                }
            case .newMonero1Title:
                AWNewMonero1Title(isPresented: $isPresented, nextAction: nextAction)
                    .environmentObject(walletVM)
            case .newMonero3SeedBackUp:
                AWSeedBackUp(
                    words: (walletVM.newMoneroWalletData.seed ?? "")
                        .components(separatedBy: CharacterSet(charactersIn: " \u{3000}"))
                        .filter { !$0.isEmpty },
                    passphrase: walletVM.newMoneroWalletData.passphrase.isEmpty ? nil : walletVM.newMoneroWalletData.passphrase,
                    backedUp: Binding(
                        get: { walletVM.newMoneroWalletData.backedUp },
                        set: { walletVM.newMoneroWalletData.backedUp = $0 }
                    ),
                    nextAction: nextAction
                )
            case .newMonero4BackUpLater:
                AWNewMonero4BackUpLater(nextAction: nextAction, backAction: backAction)
            case .newZcash1Title:
                AWNewZcash1Title(isPresented: $isPresented, nextAction: nextAction)
                    .environmentObject(walletVM)
            case .newZcash2SeedBackUp:
                AWSeedBackUp(
                    words: walletVM.newZcashWalletData.words,
                    passphrase: nil,
                    backedUp: Binding(
                        get: { walletVM.newZcashWalletData.backedUp },
                        set: { walletVM.newZcashWalletData.backedUp = $0 }
                    ),
                    nextAction: nextAction
                )
            case .newZcash3BackUpLater:
                AWNewMonero4BackUpLater(nextAction: nextAction, backAction: backAction)
            case .restoreMonero1SeedKeys:
                AWRestoreMonero1SeedKeys(isPresented: $isPresented, nextAction: nextAction)
                    .environmentObject(walletVM)
            case .restoreMonero2Title:
                AWRestoreMonero2Title(nextAction: nextAction, backAction: backAction)
                    .environmentObject(walletVM)
            case .restoreZcash1SeedKeys:
                AWRestoreZcash1SeedKeys(isPresented: $isPresented, nextAction: nextAction)
                    .environmentObject(walletVM)
            case .restoreZcash2Title:
                AWRestoreZcash2Title(nextAction: nextAction, backAction: backAction)
                    .environmentObject(walletVM)
            }
        }
        .alert("Wallet Setup Failed", isPresented: Binding(
            get: { restoreError != nil },
            set: { if !$0 { restoreError = nil } }
        )) {
            Button("OK", role: .cancel) {
                restoreError = nil
            }
        } message: {
            Text(restoreError ?? "An unknown error occurred.")
        }
    }

    func nextAction() {

        switch currentWalletType {
        case .moneroNew:
            switch currentView {
            case .newMonero1Title:
                if let earlyError = connectToWallet_New() {
                    restoreError = earlyError
                } else if let walletError = WalletManager.shared.activeWallet?.walletError {
                    WalletManager.shared.removeActiveWallet()
                    restoreError = walletError.userMessage
                } else {
                    currentView = .newMonero3SeedBackUp
                }
            case .newMonero3SeedBackUp:
                if walletVM.newMoneroWalletData.backedUp {
                    if let activeWallet = WalletManager.shared.activeWallet {
                        WalletManager.shared.clearPendingSeedBackup(for: activeWallet)
                    }
                    isPresented = false
                }
                else {
                    currentView = .newMonero4BackUpLater
                }
            case .newMonero4BackUpLater:
                isPresented = false
            default:
                break
            }
        case .zcashNew:
            switch currentView {
            case .newZcash1Title:
                if let earlyError = connectToWallet_NewZcash() {
                    restoreError = earlyError
                } else if let walletError = WalletManager.shared.activeWallet?.walletError {
                    WalletManager.shared.removeActiveWallet()
                    restoreError = walletError.userMessage
                } else {
                    currentView = .newZcash2SeedBackUp
                }
            case .newZcash2SeedBackUp:
                if walletVM.newZcashWalletData.backedUp {
                    if let activeWallet = WalletManager.shared.activeWallet {
                        WalletManager.shared.clearPendingSeedBackup(for: activeWallet)
                    }
                    isPresented = false
                }
                else {
                    currentView = .newZcash3BackUpLater
                }
            case .newZcash3BackUpLater:
                isPresented = false
            default:
                break
            }
        case .moneroRestore:
            switch currentView {
            case .restoreMonero1SeedKeys:
                currentView = .restoreMonero2Title
            case .restoreMonero2Title:
                if let earlyError = connectToWallet_Restore() {
                    restoreError = earlyError
                } else if let walletError = WalletManager.shared.activeWallet?.walletError {
                    WalletManager.shared.removeActiveWallet()
                    restoreError = walletError.userMessage
                } else {
                    isPresented = false
                }
            default:
                break
            }
        case .zcashRestore:
            switch currentView {
            case .restoreZcash1SeedKeys:
                currentView = .restoreZcash2Title
            case .restoreZcash2Title:
                if let earlyError = connectToWallet_RestoreZcash() {
                    restoreError = earlyError
                } else if let walletError = WalletManager.shared.activeWallet?.walletError {
                    WalletManager.shared.removeActiveWallet()
                    restoreError = walletError.userMessage
                } else {
                    isPresented = false
                }
            default:
                break
            }
        }
    }

    func backAction() {
        switch currentWalletType {
        case .moneroNew:
            switch currentView {
            case .newMonero4BackUpLater:
                currentView = .newMonero3SeedBackUp
            default:
                break
            }
        case .zcashNew:
            switch currentView {
            case .newZcash3BackUpLater:
                currentView = .newZcash2SeedBackUp
            default:
                break
            }
        case .moneroRestore:
            switch currentView {
            case .restoreMonero2Title:
                currentView = .restoreMonero1SeedKeys
            default:
                break
            }
        case .zcashRestore:
            switch currentView {
            case .restoreZcash2Title:
                currentView = .restoreZcash1SeedKeys
            default:
                break
            }
        }
    }

    @discardableResult
    private func connectToWallet_Restore() -> String? {

        let data = walletVM.restoreMoneroWalletData
        let wallet: MoneroWallet

        if data.isFromSeed {
            let seedArray = data.seed?
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .components(separatedBy: CharacterSet(charactersIn: " \u{3000}"))
                .filter { !$0.isEmpty }

            guard let seedArray = seedArray, !seedArray.isEmpty else {
                return "Seed phrase is empty."
            }

            if seedArray.count == 16 {
                wallet = .polyseed(seed: seedArray, passphrase: data.passphrase)
            } else if seedArray.count == 25 {
                wallet = .legacy(seed: seedArray, passphrase: data.passphrase)
            } else {
                return "Invalid seed length: \(seedArray.count) words. Expected 16 (Polyseed) or 25 (Legacy)."
            }
        } else if data.isWatchOnly {
            guard let address = data.publicAddress, !address.isEmpty,
                  let viewKey = data.viewKey, !viewKey.isEmpty else {
                return "Address and view key are both required."
            }
            wallet = .watch(address: address, viewKey: viewKey)
        } else {
            guard let address = data.publicAddress, !address.isEmpty,
                  let viewKey = data.viewKey, !viewKey.isEmpty,
                  let spendKey = data.spendKey, !spendKey.isEmpty else {
                return "Address, view key, and spend key are all required."
            }
            wallet = .keys(address: address, viewKey: viewKey, spendKey: spendKey)
        }

        var restoreHeight: UInt64? = nil
        if data.restoreHeight > 0 {
            restoreHeight = UInt64(data.restoreHeight)
        } else if let restoreDate = data.restoreDate {
            restoreHeight = UInt64(RestoreHeight.getHeight(date: restoreDate))
        } else {
            restoreHeight = 0
        }

        WalletManager.shared.addWallet(.monero(wallet, restoreHeight: restoreHeight), title: data.title ?? "", pendingSeedBackup: false)
        return nil
    }

    @discardableResult
    private func connectToWallet_New() -> String? {

        let data = walletVM.newMoneroWalletData
        let wallet: MoneroWallet

        switch data.seedType {
        case .polyseed:
            let language = data.polyseedLanguage.nativeName
            guard let newSeed = Kit.newPolyseed(language: language) else {
                return "Failed to generate Polyseed. Please try again."
            }
            data.seed = newSeed
            wallet = .polyseed(seed: newSeed.components(separatedBy: CharacterSet(charactersIn: " \u{3000}")).filter { !$0.isEmpty }, passphrase: data.passphrase)

        case .legacy:
            let language = data.legacySeedLanguage.cLibraryName
            guard let newSeed = Kit.newLegacySeed(language: language) else {
                return "Failed to generate Legacy seed. Please try again."
            }
            data.seed = newSeed
            wallet = .legacy(seed: newSeed.components(separatedBy: " "), passphrase: data.passphrase)
        }

        WalletManager.shared.addWallet(.monero(wallet, restoreHeight: nil), title: data.title ?? "")
        return nil
    }

    @discardableResult
    private func connectToWallet_RestoreZcash() -> String? {

        let data = walletVM.restoreZcashWalletData

        if data.isViewOnly {
            guard let ufvk = data.ufvk, !ufvk.isEmpty else {
                return "A viewing key is required."
            }
            WalletManager.shared.addWallet(.zcashViewOnly(ufvk: ufvk, birthday: data.birthdayHeight), title: data.title ?? "", pendingSeedBackup: false)
        } else {
            guard !data.words.isEmpty else {
                return "Seed phrase is empty."
            }
            WalletManager.shared.addWallet(.zcashRestore(mnemonic: data.words, birthday: data.birthdayHeight), title: data.title ?? "", pendingSeedBackup: false)
        }
        return nil
    }

    @discardableResult
    private func connectToWallet_NewZcash() -> String? {

        let data = walletVM.newZcashWalletData

        guard let mnemonic = try? Mnemonic.generate(wordCount: .twentyFour) else {
            return "Failed to generate wallet seed. Please try again."
        }
        data.words = mnemonic

        WalletManager.shared.addWallet(.zcashNew(mnemonic: mnemonic), title: data.title ?? "")
        return nil
    }
}
