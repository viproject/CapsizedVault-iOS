//
//  ZIP321Tests.swift
//  CapsizedVaultTests
//

import Testing
@testable import CapsizedVault

struct ZIP321Tests {

    @Test func bareAddressWithoutSchemeIsNotParsed() {
        #expect(ZIP321.parse("u1somerandomaddress") == nil)
    }

    @Test func bareURIWithNoQueryYieldsAddressOnly() {
        let request = ZIP321.parse("zcash:u1somerandomaddress")
        #expect(request?.address == "u1somerandomaddress")
        #expect(request?.amount == nil)
        #expect(request?.memo == nil)
    }

    @Test func uriWithAmountAndMemoParsesBoth() {
        // "hello" base64url-encoded without padding.
        let memoBase64URL = "aGVsbG8"
        let request = ZIP321.parse("zcash:u1somerandomaddress?amount=1.23&memo=\(memoBase64URL)")
        #expect(request?.address == "u1somerandomaddress")
        #expect(request?.amount == "1.23")
        #expect(request?.memo == "hello")
    }

    @Test func uriWithUnknownParamsIgnoresThem() {
        let request = ZIP321.parse("zcash:u1somerandomaddress?amount=0.5&label=Coffee&message=Thanks")
        #expect(request?.address == "u1somerandomaddress")
        #expect(request?.amount == "0.5")
    }

    @Test func multiRecipientURIIsRejected() {
        #expect(ZIP321.parse("zcash:u1first?amount=1&address.1=u1second&amount.1=2") == nil)
    }

    @Test func emptyAddressBeforeQueryIsRejected() {
        #expect(ZIP321.parse("zcash:?amount=1") == nil)
    }
}
