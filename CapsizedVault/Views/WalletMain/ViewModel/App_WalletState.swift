//
//  WalletState.swift
//  CapsizedVault
//
//  Created by Dmitrij on 02/02/2026.
//

import Combine
import Foundation
import CapsizedMoneroKit

class App_WalletState: ObservableObject, CapsizedMoneroKitDelegate {
    
    @Published var balance: BalanceInfo = .init(all: 0, unlocked: 0)
    @Published var transactions: [TransactionInfo] = []
    @Published var walletState: WalletState = .notSynced(error: .notStarted)

    @Published var isConnected: Bool = false

    var isSynchronized: Bool {
        if case .synced = walletState {
            return true
        }
        return false
    }

    
    func balancesDidChange(balanceInfos: [CapsizedMoneroKit.BalanceInfo]) {
        //
    }

    func transactionsUpdated(inserted: [TransactionInfo], updated: [TransactionInfo]) {
        DispatchQueue.main.async {
            self.transactions = inserted + updated
        }
    }

    func walletStateDidChange(state: WalletState) {
        DispatchQueue.main.async {
            self.walletState = state
        }
    }

    func subAddressesUpdated(subaddresses: [SubAddress]) {}

    func activeNodeDidChange(node: Node) {}

    func clearData() {
        balance = .init(all: 0, unlocked: 0)
        transactions = []
        walletState = .notSynced(error: .notStarted)
    }
}

