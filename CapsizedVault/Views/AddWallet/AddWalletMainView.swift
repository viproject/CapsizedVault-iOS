//
//  AddNewWalletMainView.swift
//  CapsizedVault
//
//  Created by Dmitrij on 19/12/2025.
//

import SwiftUI
import CapsizedMoneroKit
import HsToolKit

enum AWCurrentView {
    case newMonero1Title, newMonero3SeedBackUp, newMonero4BackUpLater
    case restoreMonero1SeedKeys, restoreMonero2Title
}

enum AWWalletType {
    case moneroNew, moneroRestore
}

struct AddWalletMainView: View {

    
    @Binding var isPresented: Bool
    let currentWalletType: AWWalletType
    
    @State private var currentView: AWCurrentView = .newMonero1Title
    @State private var restoreError: String?
    @StateObject private var walletVM = AddWalletViewModel()
    
    let daemonAddress: String = "http://xmr-node.cakewallet.com:18081"
    let restoreHeight: String = "\(RestoreHeight.getHeight(date: Date()))"

    init(isPresented: Binding<Bool>, currentWalletType: AWWalletType) {
        self._isPresented = isPresented
        self.currentWalletType = currentWalletType
        
        switch currentWalletType {
        case .moneroNew:
            _currentView = State(initialValue: .newMonero1Title)
        case .moneroRestore:
            _currentView = State(initialValue: .restoreMonero1SeedKeys)
        }
    }

    
    var body: some View {
        Group {
            switch currentView {
            case .newMonero1Title:
                AWNewMonero1Title(isPresented: $isPresented, nextAction: nextAction)
                    .environmentObject(walletVM)
            case .newMonero3SeedBackUp:
                AWNewMonero3SeedBackUp(nextAction: nextAction)
                    .environmentObject(walletVM)
            case .newMonero4BackUpLater:
                AWNewMonero4BackUpLater(nextAction: nextAction, backAction: backAction)
            case .restoreMonero1SeedKeys:
                AWRestoreMonero1SeedKeys(isPresented: $isPresented, nextAction: nextAction)
                    .environmentObject(walletVM)
            case .restoreMonero2Title:
                AWRestoreMonero2Title(nextAction: nextAction, backAction: backAction)
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
        
        if currentWalletType == .moneroNew {
            switch currentView {
            case .newMonero1Title:
                if let earlyError = connectToWallet_New() {
                    restoreError = earlyError
                } else if let walletError = WalletManager.shared.activeWallet?.walletError {
                    WalletManager.shared.removeActiveWallet()
                    restoreError = walletError
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
        }
        else if currentWalletType == .moneroRestore {
            switch currentView {
            case .restoreMonero1SeedKeys:
                currentView = .restoreMonero2Title
            case .restoreMonero2Title:
                if let earlyError = connectToWallet_Restore() {
                    restoreError = earlyError
                } else if let walletError = WalletManager.shared.activeWallet?.walletError {
                    WalletManager.shared.removeActiveWallet()
                    restoreError = walletError
                } else {
                    isPresented = false
                }
            default:
                break
            }
        }
    }
    
    func backAction() {
        if currentWalletType == .moneroNew {
            switch currentView {
            case .newMonero4BackUpLater:
                currentView = .newMonero3SeedBackUp
            default:
                break
            }
        }
        else if currentWalletType == .moneroRestore {
            switch currentView {
            case .restoreMonero2Title:
                currentView = .restoreMonero1SeedKeys
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

        WalletManager.shared.addNewMoneroWallet(title: data.title ?? "", moneroWallet: wallet, pendingSeedBackup: false, restoreHeight: restoreHeight)
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

        WalletManager.shared.addNewMoneroWallet(title: data.title ?? "", moneroWallet: wallet)
        return nil
    }
}
