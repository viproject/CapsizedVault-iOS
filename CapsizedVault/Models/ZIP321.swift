//
//  ZIP321.swift
//  CapsizedVault
//

import Foundation

/// Minimal ZIP-321 (https://zips.z.cash/zip-0321) payment URI parser, used only to prefill
/// `SendZECView`'s fields when a scanned/pasted value is a `zcash:` URI instead of a bare
/// address — the actual proposal is still built from the parsed address/amount/memo through
/// the normal `estimateFee`/`send` path, not from the URI directly.
///
/// Single recipient only: a URI with indexed params (`address.1=`, `amount.1=`, ...) describes
/// a multi-output payment this app has no UI for, so it's rejected outright rather than
/// silently sending to just the first recipient.
nonisolated enum ZIP321 {
    struct PaymentRequest: Equatable {
        let address: String
        let amount: String?
        let memo: String?
    }

    static func parse(_ uriString: String) -> PaymentRequest? {
        guard uriString.hasPrefix("zcash:") else { return nil }
        let rest = uriString.dropFirst("zcash:".count)
        let parts = rest.split(separator: "?", maxSplits: 1, omittingEmptySubsequences: false)
        let address = String(parts.first ?? "")
        guard !address.isEmpty else { return nil }

        var amount: String?
        var memo: String?
        if parts.count > 1 {
            for pair in parts[1].split(separator: "&") {
                let keyValue = pair.split(separator: "=", maxSplits: 1)
                guard keyValue.count == 2 else { continue }
                let key = String(keyValue[0])
                // A dotted/indexed key (`address.1`, `amount.0`, ...) means this URI
                // addresses more than one recipient — bail rather than guess.
                if key.contains(".") { return nil }
                let value = String(keyValue[1]).removingPercentEncoding ?? String(keyValue[1])
                switch key {
                case "amount":
                    amount = value
                case "memo":
                    memo = decodeBase64URLMemo(value)
                default:
                    continue
                }
            }
        }
        return PaymentRequest(address: address, amount: amount, memo: memo)
    }

    private static func decodeBase64URLMemo(_ base64url: String) -> String? {
        var base64 = base64url.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        while base64.count % 4 != 0 { base64 += "=" }
        guard let data = Data(base64Encoded: base64) else { return nil }
        return String(data: data, encoding: .utf8)
    }
}
