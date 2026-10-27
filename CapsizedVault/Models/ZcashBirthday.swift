//
//  ZcashBirthday.swift
//  CapsizedVault
//
//  Converts a restore date to a block height on the app side, for the restore/view-only
//  add-wallet screens — the SDK's own date estimator needs a running `SDKSynchronizer`
//  instance, which doesn't exist yet at that point in the flow.
//

import Foundation

nonisolated enum ZcashBirthday {

    /// Mainnet Sapling activation — also the restore-birthday fallback when no date/height
    /// is given at all (see `WalletFactory.zcashSaplingActivationHeight`).
    private static let saplingActivationHeight = 419_200
    private static let saplingActivationDate = Date(timeIntervalSince1970: 1_540_668_600) // 2018-10-27T18:30:00Z

    /// Mainnet Blossom activation, which halved the target block time from 150s to 75s.
    private static let blossomActivationHeight = 653_600
    private static let blossomActivationDate = Date(timeIntervalSince1970: 1_576_088_523) // 2019-12-11T18:02:03Z

    private static let preBlossomBlockSeconds: TimeInterval = 150
    private static let postBlossomBlockSeconds: TimeInterval = 75

    /// Rounds the estimate down by about two weeks of post-Blossom blocks. An early
    /// birthday only costs extra scanning — never missed funds — so this errs early.
    private static let safetyMarginBlocks = Int((14 * 24 * 3600) / postBlossomBlockSeconds)

    /// Estimates a reorg-safe, never-too-late block height for a restore birthday. Dates
    /// at or before Sapling activation (and any date in the future) clamp to the nearest
    /// bound rather than extrapolating.
    static func height(for date: Date) -> Int {
        let clamped = min(date, Date())
        guard clamped > saplingActivationDate else { return saplingActivationHeight }

        guard clamped > blossomActivationDate else {
            let elapsed = clamped.timeIntervalSince(saplingActivationDate)
            let blocks = Int(elapsed / preBlossomBlockSeconds)
            return max(saplingActivationHeight, saplingActivationHeight + blocks - safetyMarginBlocks)
        }

        let elapsed = clamped.timeIntervalSince(blossomActivationDate)
        let blocks = Int(elapsed / postBlossomBlockSeconds)
        return max(saplingActivationHeight, blossomActivationHeight + blocks - safetyMarginBlocks)
    }
}
