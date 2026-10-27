//
//  ZcashSeedValidationTests.swift
//  CapsizedVaultTests
//
//  Covers the HdWalletKit `Mnemonic` behavior `AWRestoreZcash1SeedKeys` relies on for its
//  24-word English-only seed validation.
//

import Testing
import Foundation
import HdWalletKit
@testable import CapsizedVault

struct ZcashSeedValidationTests {

    @Test func validTwentyFourWordEnglishSeedPasses() throws {
        let words = try Mnemonic.generate(wordCount: .twentyFour)
        #expect(words.count == 24)
        #expect(Mnemonic.language(words: words) == .english)
        try Mnemonic.validate(words: words)
    }

    @Test func twelveWordSeedIsNotTwentyFourWords() throws {
        let words = try Mnemonic.generate(wordCount: .twelve)
        #expect(words.count != 24)
    }

    @Test func nonEnglishWordlistIsNotRecognizedAsEnglish() throws {
        let words = try Mnemonic.generate(wordCount: .twentyFour, language: .spanish)
        #expect(Mnemonic.language(words: words) != .english)
    }

    @Test func tamperedChecksumFailsValidation() throws {
        var words = try Mnemonic.generate(wordCount: .twentyFour)
        let englishWords = Mnemonic.wordList(for: .english).map(String.init)
        let replacement = englishWords.first { $0 != words[0] } ?? words[0]
        words[0] = replacement

        #expect(throws: Error.self) {
            try Mnemonic.validate(words: words)
        }
    }
}
