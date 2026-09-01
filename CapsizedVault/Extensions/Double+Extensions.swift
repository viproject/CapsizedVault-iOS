//
//  Double+Extensions.swift
//  CapsizedVault
//
//  Created by Dmitrij on 23/05/2026.
//

import Foundation

extension Double {
    /// Trimmed to up to 12 decimal places — used for detail fields (fee, tx amount in details view, etc.)
    var xmrFormatted: String {
        let result = String(format: "%.12f", self)
            .replacingOccurrences(of: #"0+$"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"\.$"#, with: ".00", options: .regularExpression)
        return result
    }

    /// Trimmed to up to 8 decimal places — used for balance card and transaction list amounts.
    var xmrFormattedBalance: String {
        let result = String(format: "%.8f", self)
            .replacingOccurrences(of: #"0+$"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"\.$"#, with: ".00", options: .regularExpression)
        return result
    }
}
