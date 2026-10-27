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

    /// Default nodes/servers for a coin. Zcash servers land when Zcash server support does
    /// (plan §2 "ZcashServerSettingsView") — empty for now.
    static func defaults(for coin: Coin) -> [Node] {
        switch coin {
        case .monero: return moneroDefaultNodes
        case .zcash: return []
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

    /// Custom nodes saved by the user. `NodeData` has no `coin` field yet (added alongside
    /// Realm schema 9), so every saved custom node is implicitly Monero until then — matching
    /// today's behavior exactly.
    static func custom(for coin: Coin) -> [NodeData] {
        RealmManager.shared.getCustomNodes()
    }

    @discardableResult
    static func addCustomNode(urlString: String, isTrusted: Bool, login: String, password: String, coin: Coin) -> Bool {
        RealmManager.shared.addCustomNode(urlString: urlString, isTrusted: isTrusted, login: login, password: password)
    }

    @discardableResult
    static func updateCustomNode(oldURLString: String, newURLString: String, isTrusted: Bool, login: String, password: String, coin: Coin) -> Bool {
        RealmManager.shared.updateCustomNode(oldURLString: oldURLString, newURLString: newURLString, isTrusted: isTrusted, login: login, password: password)
    }

    @discardableResult
    static func removeCustomNode(urlString: String, coin: Coin) -> Bool {
        RealmManager.shared.removeCustomNode(urlString: urlString)
    }
}
