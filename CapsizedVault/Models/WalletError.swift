//
//  WalletError.swift
//  CapsizedVault
//

import Foundation

/// A coin-neutral error every wallet maps its underlying errors into, so views show one
/// consistent set of messages regardless of which coin raised the error.
nonisolated enum WalletError: Error, Equatable, Sendable {
    case insufficientFunds(available: CoinAmount)
    case invalidAddress
    case nodeUnavailable
    case torUnavailable
    case walletFilesMissing
    case recoveryFailed(String)
    case duplicateViewingKey
    case paramsDownloadFailed
    case unknown(String)

    var userMessage: String {
        switch self {
        case .insufficientFunds(let available):
            return "Insufficient funds. Available balance: \(available.formatted(style: .balance)) \(available.coin.ticker)."
        case .invalidAddress:
            return "Invalid address."
        case .nodeUnavailable:
            return "Could not connect to the node."
        case .torUnavailable:
            return "Could not connect over Tor."
        case .walletFilesMissing:
            return "Wallet files are missing or corrupted. Please restore the wallet from seed, keys, or a view key."
        case .recoveryFailed(let message):
            return "Wallet recovery failed: \(message)"
        case .duplicateViewingKey:
            return "This viewing key is already in this wallet."
        case .paramsDownloadFailed:
            return "Could not download the files needed to send. Check your connection and try again."
        case .unknown(let message):
            return message
        }
    }
}
