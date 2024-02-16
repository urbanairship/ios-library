/* Copyright Airship and Contributors */

import Foundation

/// Keychain credentials
/// - Note: for internal use only.  :nodoc:
public struct AirshipKeychainCredentials: Sendable {

    /// The username
    public let username: String

    /// The password
    public let password: String

    /// Constructor
    /// - Parameters:
    ///     - username: The username
    ///     - password: The password
    public init(username: String, password: String) {
        self.username = username
        self.password = password
    }
}

/// Keychain access
/// - Note: for internal use only.  :nodoc:
public protocol AirshipKeychainAccessProtocol: Sendable {
    /// Writes credentials to the keychain for the given identifier.
    /// - Parameters:
    ///     - credentials: The credentials to save
    ///     - identifier: The credential's identifier
    ///     - appKey: The app key
    /// - Returns: `true` if the data was written, otherwise `false`.
    func writeCredentials(
        _ credentials: AirshipKeychainCredentials,
        identifier: String,
        appKey: String
    ) async -> Bool

    /// Deletes credentials for the given identifier.
    /// - Parameters:
    ///     - identifier: The credential's identifier
    ///     - appKey: The app key
    func deleteCredentials(
        identifier: String,
        appKey: String
    ) async

    /// Reads credentials from the keychain synchronously.
    ///
    /// - NOTE: This method could take a long time to call, it should not
    /// be called on the main queue.
    ///
    /// - Parameters:
    ///     - identifier: The credential's identifier
    ///     - appKey: The app key
    /// - Returns: The credentials if found.
    func readCredentails(
        identifier: String,
        appKey: String
    ) async -> AirshipKeychainCredentials?
}

/// Keychain access
/// - Note: for internal use only.  :nodoc:
public final class AirshipKeychainAccess: AirshipKeychainAccessProtocol {

    public static let shared = AirshipKeychainAccess()

    // Dispatch queue to prevent blocking any tasks
    private let dispatchQueue: AirshipUnsafeSendableWrapper<DispatchQueue> = AirshipUnsafeSendableWrapper(
        DispatchQueue(
            label: "com.urbanairship.dispatcher.keychain",
            qos: .utility
        )
    )

    public func writeCredentials(
        _ credentials: AirshipKeychainCredentials,
        identifier: String,
        appKey: String
    ) async -> Bool {
        let service = service(appKey: appKey)
        return await self.dispatch { [service] in
            let result = Keychain.writeCredentials(
                credentials,
                identifier: identifier,
                service: service
            )

            // Write to old location in case of a downgrade
            if let bundleID = Bundle.main.bundleIdentifier {
                let _ = Keychain.writeCredentials(
                    credentials,
                    identifier: identifier,
                    service: bundleID
                )
            }


            return result
        }
    }

    public func deleteCredentials(identifier: String, appKey: String) async {
        let service = service(appKey: appKey)

        await self.dispatch { [service] in
            Keychain.deleteCredentials(
                identifier: identifier,
                service: service
            )

            // Delete old
            if let bundleID = Bundle.main.bundleIdentifier {
                Keychain.deleteCredentials(
                    identifier: identifier,
                    service: bundleID
                )
            }
        }
    }

    public func readCredentails(
        identifier: String,
        appKey: String
    ) async -> AirshipKeychainCredentials? {

        let service = service(appKey: appKey)

        return await self.dispatch { [service] in
            if let credentials = Keychain.readCredentials(
                identifier: identifier,
                service: service
            ) {
                return credentials
            }

            // If we do not have a new value, check
            // the old service location
            if let bundleID = Bundle.main.bundleIdentifier {

                let old = Keychain.readCredentials(
                    identifier: identifier,
                    service: bundleID
                )

                if let old = old {
                    // Migrate old data to new service location
                    let _ = Keychain.writeCredentials(
                        old,
                        identifier: identifier,
                        service: service
                    )
                    return old
                }
            }
            return nil
        }

    }

    private func dispatch<T>(block: @escaping @Sendable () -> T) async -> T {
        return await withCheckedContinuation { continuation in
            dispatchQueue.value.async {
                continuation.resume(returning: block())
            }
        }
    }

    private func service(appKey: String) -> String {
        return "\(Bundle.main.bundleIdentifier ?? "").airship.\(appKey)"
    }
}


/// Helper that wraps the actual keychain calls
private struct Keychain {
    static func writeCredentials(
        _ credentials: AirshipKeychainCredentials,
        identifier: String,
        service: String
    ) -> Bool {
        guard
            let identifierData = identifier.data(using: .utf8),
            let passwordData = credentials.password.data(using: .utf8)
        else {
            return false
        }

        deleteCredentials(identifier: identifier, service: service)

        let addquery: [String: Any] = [
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrGeneric as String: identifierData,
            kSecAttrAccount as String: credentials.username,
            kSecValueData as String: passwordData,
        ]

        let status = SecItemAdd(addquery as CFDictionary, nil)
        return status == errSecSuccess
    }

    static func deleteCredentials(
        identifier: String,
        service: String
    ) {
        guard let identifierData = identifier.data(using: .utf8)
        else {
            return
        }

        let deleteQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrGeneric as String: identifierData,
        ]

        SecItemDelete(deleteQuery as CFDictionary)
    }

    static func readCredentials(
        identifier: String,
        service: String
    ) -> AirshipKeychainCredentials? {
        guard let identifierData = identifier.data(using: .utf8) else {
            return nil
        }

        let searchQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecMatchLimit as String: kSecMatchLimitOne,
            kSecAttrService as String: service,
            kSecAttrGeneric as String: identifierData,
            kSecReturnAttributes as String: true,
            kSecReturnData as String: true,
        ]


        var item: CFTypeRef?
        let status = SecItemCopyMatching(searchQuery as CFDictionary, &item)
        guard status == errSecSuccess else {
            return nil
        }

        guard let existingItem = item as? [String: Any] else {
            return nil
        }

        guard let passwordData = existingItem[kSecValueData as String] as? Data,
              let password = String(
                data: passwordData,
                encoding: String.Encoding.utf8
              ),
              let username = existingItem[kSecAttrAccount as String] as? String
        else {
            return nil
        }

        let credentials = AirshipKeychainCredentials(
            username: username,
            password: password
        )

        let attrAccessible = existingItem[kSecAttrAccessible as String] as? String
        if attrAccessible != (kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly as String) {
            updateThisDeviceOnly(credentials: credentials, identifier: identifier, service: service)
        }

        return credentials
    }

    static func updateThisDeviceOnly(credentials: AirshipKeychainCredentials, identifier: String, service: String) {
        guard
            let identifierData = identifier.data(using: .utf8),
            let passwordData = credentials.password.data(using: .utf8)
        else {
            return
        }

        let updateQuery: [String: Any] = [
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
            kSecValueData as String: passwordData
        ]

        let searchQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrGeneric as String: identifierData,
            kSecAttrAccount as String: credentials.username
        ]

        let updateStatus = SecItemUpdate(searchQuery as CFDictionary, updateQuery as CFDictionary)

        if (updateStatus == errSecSuccess) {
            AirshipLogger.trace("Updated keychain value \(identifier) to this device only")
        } else {
            AirshipLogger.debug("Failed to update keychain value \(identifier) status:\(updateStatus)")
        }
    }
}
