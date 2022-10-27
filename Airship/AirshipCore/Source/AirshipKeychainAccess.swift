/* Copyright Airship and Contributors */

import Foundation

/// Keychain credentials
/// - Note: for internal use only.  :nodoc:
@objc(UAirshipKeychainCredentials)
public class AirshipKeychainCredentials: NSObject {

    /// The username
    @objc
    public let username: String

    /// The password
    @objc
    public let password: String

    /// Constructor
    /// - Parameters:
    ///     - username: The username
    ///     - password: The password
    @objc
    public init(username: String, password: String) {
        self.username = username
        self.password = password
    }
}

/// Keychain access
/// - Note: for internal use only.  :nodoc:
@objc(UAirshipKeychainAccess)
public class AirshipKeychainAccess: NSObject {

    private let appKey: String
    private let dispatcher = UADispatcher.serialUtility()
    private let service: String

    /// Creates a key chain access for data stored under the app key.
    /// - Parameters:
    ///     - appKey: The app key
    @objc
    public init(appKey: String) {
        self.appKey = appKey
        self.service = "\(Bundle.main.bundleIdentifier ?? "").airship.\(appKey)"
    }

    /// Writes credentials to the keychain for the given identifier.
    /// - Parameters:
    ///     - credentials: The credentails to save
    ///     - identifier: The credential's identifier
    ///     - completionHandler: The completion handler with the result
    @objc
    public func writeCredentials(
        _ credentials: AirshipKeychainCredentials,
        identifier: String,
        completionHandler: ((Bool) -> Void)?
    ) {
        dispatcher.dispatchAsync {
            let result = Keychain.writeCredentials(
                credentials,
                identifier: identifier,
                service: self.service
            )

            // Delete old
            if let bundleID = Bundle.main.bundleIdentifier {
                Keychain.deleteCredentials(
                    identifier: identifier,
                    service: bundleID
                )
            }

            completionHandler?(result)
        }
    }

    /// Deltes credentials for the given identifier.
    /// - Parameters:
    ///     - identifier: The credential's identifier
    @objc
    public func deleteCredentials(identifier: String) {
        self.dispatcher.dispatchAsync {
            Keychain.deleteCredentials(
                identifier: identifier,
                service: self.service
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

    /// Reads credentials from the keychain synchronously.
    ///
    /// - NOTE: This method could take a long time to call, it should not
    /// be called on the main queue.
    ///
    /// - Parameters:
    ///     - identifier: The credential's identifier
    /// - Returns: The credentials if found.
    @objc
    public func readCredentialsSync(
        identifier: String
    ) -> AirshipKeychainCredentials? {
        var credentials: AirshipKeychainCredentials?
        self.dispatcher.dispatchSync {
            credentials = self.readCredentialsHelper(
                identifier: identifier
            )
        }
        return credentials
    }

    /// Reads credentials from the keychain.
    /// - Parameters:
    ///     - identifier: The credential's identifier
    ///     - completionHandler: The completion handler with the result
    @objc
    public func readCredentials(
        identifier: String,
        completionHandler: @escaping(AirshipKeychainCredentials?
    ) -> Void) {
        self.dispatcher.dispatchAsync {
            let credentials = self.readCredentialsHelper(
                identifier: identifier
            )
            completionHandler(credentials)
        }
    }

    /// Helper method that migrates data from the old storage location to the new on read.
    private func readCredentialsHelper(identifier: String) -> AirshipKeychainCredentials? {
        var credentials = Keychain.readCredentials(
            identifier: identifier,
            service: self.service
        )

        // If we do not have a new value, check
        // the old service location
        if credentials == nil, let bundleID = Bundle.main.bundleIdentifier {

            credentials = Keychain.readCredentials(
                identifier: identifier,
                service: bundleID
            )

            if let credentials = credentials {
                // Migrate old data to new service location
                let result = Keychain.writeCredentials(
                    credentials,
                    identifier: identifier,
                    service: self.service
                )
                if (result) {
                    Keychain.deleteCredentials(
                        identifier: identifier,
                        service: bundleID
                    )
                } else {
                    AirshipLogger.error("Failed to migrate credentials")
                }
            }
        }

        return credentials
    }
}

/// Helper that wraps the actual keychain calls
fileprivate struct Keychain {
    static func writeCredentials(
        _ credentials: AirshipKeychainCredentials,
        identifier: String,
        service: String
    ) -> Bool {
        guard let identifierData = identifier.data(using: .utf8),
              let passwordData = credentials.password.data(
                using: .utf8
              )
        else {
            return false
        }

        deleteCredentials(identifier: identifier, service: service)

        let addquery: [String: Any] = [
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock,
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrGeneric as String: identifierData,
            kSecAttrAccount as String: credentials.username,
            kSecValueData as String: passwordData
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
            kSecReturnData as String: true
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(searchQuery as CFDictionary, &item)
        guard status == errSecSuccess else {
            return nil
        }

        guard let existingItem = item as? [String : Any],
              let passwordData = existingItem[kSecValueData as String] as? Data,
              let password = String(data: passwordData, encoding: String.Encoding.utf8),
              let username = existingItem[kSecAttrAccount as String] as? String
        else {
            return nil
        }

        return AirshipKeychainCredentials(
            username: username,
            password: password
        )
    }
}
