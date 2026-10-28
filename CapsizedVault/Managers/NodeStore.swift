//
//  NodeStore.swift
//  CapsizedVault
//
//  Node and server lists, per coin. Replaces the static node functions that used to live on
//  WalletManager.
//

import Foundation
import CapsizedMoneroKit

enum NodeStore {

    static let moneroDefaultNodes: [Node] = [
        Node(url: URL(string: "https://xmr-node.cakewallet.com:18081")!, isTrusted: false),
        Node(url: URL(string: "https://node.monerodevs.org:18089")!, isTrusted: false),
        Node(url: URL(string: "https://nodes.hashvault.pro:18081")!, isTrusted: false),
        Node(url: URL(string: "https://monero.stackwallet.com:18081")!, isTrusted: false),
        Node(url: URL(string: "https://node.xmr.rocks:18089")!, isTrusted: false),
        Node(url: URL(string: "https://xmr-de.boldsuck.org:18081")!, isTrusted: false),
    ]

    /// Public lightwalletd servers, taken from ZcashLightClientKit's own example app's known-good
    /// list. All TLS on port 443. `isTrusted` is unused for Zcash (no RPC-auth concept here).
    static let zcashDefaultServers: [Node] = [
        Node(url: URL(string: "https://zec.rocks:443")!, isTrusted: false),
        Node(url: URL(string: "https://na.zec.rocks:443")!, isTrusted: false),
        Node(url: URL(string: "https://eu.zec.rocks:443")!, isTrusted: false),
        Node(url: URL(string: "https://sa.zec.rocks:443")!, isTrusted: false),
        Node(url: URL(string: "https://ap.zec.rocks:443")!, isTrusted: false),
    ]

    /// Default nodes/servers for a coin.
    static func defaults(for coin: Coin) -> [Node] {
        switch coin {
        case .monero: return moneroDefaultNodes
        case .zcash: return zcashDefaultServers
        }
    }

    /// Defaults plus any custom nodes not already covered by a default URL.
    static func all(for coin: Coin) -> [Node] {
        let defaultNodes = defaults(for: coin)
        let customNodes = custom(for: coin).compactMap { nodeData -> Node? in
            guard let url = URL(string: nodeData.urlString) else { return nil }
            let credentials = nodeData.credentials
            return Node(
                url: url,
                isTrusted: nodeData.isTrusted,
                login: credentials.login.isEmpty ? nil : credentials.login,
                password: credentials.password.isEmpty ? nil : credentials.password
            )
        }
        let defaultURLs = Set(defaultNodes.map(\.url))
        let uniqueCustom = customNodes.filter { !defaultURLs.contains($0.url) }
        return defaultNodes + uniqueCustom
    }

    /// Custom nodes saved by the user, scoped to `coin` via `NodeData.coin`.
    static func custom(for coin: Coin) -> [NodeData] {
        RealmManager.shared.getCustomNodes(coin: coin)
    }

    @discardableResult
    static func addCustomNode(urlString: String, isTrusted: Bool, login: String, password: String, coin: Coin) -> Bool {
        RealmManager.shared.addCustomNode(urlString: urlString, isTrusted: isTrusted, login: login, password: password, coin: coin)
    }

    @discardableResult
    static func updateCustomNode(oldURLString: String, newURLString: String, isTrusted: Bool, login: String, password: String, coin: Coin) -> Bool {
        RealmManager.shared.updateCustomNode(oldURLString: oldURLString, newURLString: newURLString, isTrusted: isTrusted, login: login, password: password, coin: coin)
    }

    @discardableResult
    static func removeCustomNode(urlString: String, coin: Coin) -> Bool {
        RealmManager.shared.removeCustomNode(urlString: urlString, coin: coin)
    }
}
