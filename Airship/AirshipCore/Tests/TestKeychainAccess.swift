/* Copyright Airship and Contributors */

@_spi(AirshipInternal) @testable import AirshipCore
import Foundation

// Test keychain that performs its in the same queueing as the real AirshipKeyChainAccess
final class TestKeyChainAccess: AirshipKeychainAccessProtocol, @unchecked Sendable {
    var storedCredentials: [String: AirshipKeychainCredentials] = [:]
    var readError: OSStatus? = nil
    var writeSucceeds: Bool = true
    private let dispatchQueue: DispatchQueue = DispatchQueue(
        label: "com.urbanairship.dispatcher.keychain",
        qos: .utility
    )

    public func writeCredentials(
        _ credentials: AirshipKeychainCredentials,
        identifier: String,
        appKey: String
    ) async -> Bool {
        let key = "\(appKey).\(identifier)"
        return await self.dispatch {
            guard self.writeSucceeds else {
                return false
            }
            self.storedCredentials[key] = credentials
            return true
        }
    }

    public func deleteCredentials(identifier: String, appKey: String) async {
        let key = "\(appKey).\(identifier)"
        return await self.dispatch {
            self.storedCredentials[key] = nil
        }
    }

    public func readCredentails(
        identifier: String,
        appKey: String
    ) async -> AirshipKeychainReadResult {
        let key = "\(appKey).\(identifier)"
        return await self.dispatch {
            if let readError = self.readError {
                return .error(readError)
            }
            if let credentials = self.storedCredentials[key] {
                return .success(credentials)
            }
            return .itemNotFound
        }
    }

    // Not really needed for this class but it matches the behavior of the real
    // keychain access
    private func dispatch<T>(block: @escaping @Sendable () -> T) async -> T {
        return await withCheckedContinuation { continuation in
            dispatchQueue.async {
                continuation.resume(returning: block())
            }
        }
    }
}
