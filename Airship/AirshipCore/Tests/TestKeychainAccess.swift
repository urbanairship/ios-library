/* Copyright Airship and Contributors */

@testable import AirshipCore
import Foundation

// Test keychain that performs its in the same queueing as the real AirshipKeyChainAccess
final class TestKeyChainAccess: AirshipKeychainAccessProtocol, @unchecked Sendable {
    var storedCredentials: [String: AirshipKeychainCredentials] = [:]
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
    ) async -> AirshipKeychainCredentials? {
        let key = "\(appKey).\(identifier)"
        return await self.dispatch {
            return self.storedCredentials[key]
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
