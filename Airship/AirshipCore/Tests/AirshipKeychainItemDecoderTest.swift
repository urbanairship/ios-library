/* Copyright Airship and Contributors */

import Testing
import Foundation

@_spi(AirshipInternal) @testable import AirshipCore

struct AirshipKeychainItemDecoderTest {
    @Test
    func decodesValidItem() {
        let item: [String: Any] = [
            kSecValueData as String: Data("secret".utf8),
            kSecAttrAccount as String: "user"
        ]
        #expect(
            AirshipKeychainItemDecoder.credentials(from: item) ==
            AirshipKeychainCredentials(username: "user", password: "secret")
        )
    }

    @Test
    func nonUTF8ValueIsUndecodable() {
        let item: [String: Any] = [
            kSecValueData as String: Data([0xFF, 0xFE, 0xFD]),
            kSecAttrAccount as String: "user"
        ]
        #expect(AirshipKeychainItemDecoder.credentials(from: item) == nil)
    }

    @Test
    func missingAccountIsUndecodable() {
        let item: [String: Any] = [kSecValueData as String: Data("secret".utf8)]
        #expect(AirshipKeychainItemDecoder.credentials(from: item) == nil)
    }

    @Test
    func missingValueIsUndecodable() {
        let item: [String: Any] = [kSecAttrAccount as String: "user"]
        #expect(AirshipKeychainItemDecoder.credentials(from: item) == nil)
    }
}

struct AirshipKeychainReadResolverTest {
    private let current = AirshipKeychainCredentials(username: "a", password: "current")
    private let old = AirshipKeychainCredentials(username: "a", password: "old")

    @Test
    func currentSuccessSkipsLegacy() {
        var legacyCalled = false
        let result = AirshipKeychainReadResolver.resolve(current: .success(current)) {
            legacyCalled = true
            return .success(old)
        }
        #expect(result == .success(current))
        #expect(!legacyCalled)
    }

    @Test
    func currentErrorSkipsLegacy() {
        var legacyCalled = false
        let result = AirshipKeychainReadResolver.resolve(current: .error(errSecMissingEntitlement)) {
            legacyCalled = true
            return .success(old)
        }
        #expect(result == .error(errSecMissingEntitlement))
        #expect(!legacyCalled)
    }

    @Test
    func currentNotFoundFallsBackToLegacy() {
        #expect(
            AirshipKeychainReadResolver.resolve(current: .itemNotFound) { .success(old) } ==
            .success(old)
        )
        #expect(
            AirshipKeychainReadResolver.resolve(current: .itemNotFound) { .error(errSecInteractionNotAllowed) } ==
            .error(errSecInteractionNotAllowed)
        )
        #expect(
            AirshipKeychainReadResolver.resolve(current: .itemNotFound) { .itemNotFound } ==
            .itemNotFound
        )
    }
}
