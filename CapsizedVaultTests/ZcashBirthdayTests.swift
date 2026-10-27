//
//  ZcashBirthdayTests.swift
//  CapsizedVaultTests
//

import Testing
import Foundation
@testable import CapsizedVault

struct ZcashBirthdayTests {

    @Test func datesAtOrBeforeSaplingActivationClampToSaplingHeight() {
        let farPast = Date(timeIntervalSince1970: 0)
        #expect(ZcashBirthday.height(for: farPast) == 419_200)
    }

    @Test func aFutureDateClampsToTheSameHeightAsNow() {
        let now = Date()
        let future = now.addingTimeInterval(60 * 60 * 24 * 365)
        #expect(ZcashBirthday.height(for: future) == ZcashBirthday.height(for: now))
    }

    @Test func laterDatesProduceHigherHeights() {
        let earlier = Date(timeIntervalSince1970: 1_600_000_000) // 2020-09-13
        let later = Date(timeIntervalSince1970: 1_700_000_000) // 2023-11-14
        #expect(ZcashBirthday.height(for: later) > ZcashBirthday.height(for: earlier))
    }

    @Test func heightNeverGoesBelowSaplingActivation() {
        let anyDate = Date(timeIntervalSince1970: 1_600_000_000)
        #expect(ZcashBirthday.height(for: anyDate) >= 419_200)
    }
}
