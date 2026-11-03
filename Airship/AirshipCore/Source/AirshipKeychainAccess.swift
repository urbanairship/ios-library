/* Copyright Airship and Contributors */

public import Foundation
@_spi(AirshipInternal) import AirshipBasement

/// Keychain credentials
/// - Note: For internal use only. :nodoc:
@_spi(AirshipInternal)
public struct AirshipKeychainCredentials: Sendable, Equatable {

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

/// Result of a keychain read.
/// Distinguishes a missing item from an unexpected `OSStatus` so callers
/// do not treat failures such as `errSecMissingEntitlement` as "not found".
/// - Note: For internal use only. :nodoc:
@_spi(AirshipInternal)
public enum AirshipKeychainReadResult: Sendable, Equatable {
    /// Credentials were found.
    case success(AirshipKeychainCredentials)
    /// No usable item exists for the identifier (`errSecItemNotFound`, or an
    /// existing item that cannot be decoded and should be overwritten).
    case itemNotFound
    /// The keychain returned an unexpected status.
    case error(OSStatus)
}

/// Keychain access
/// - Note: For internal use only. :nodoc:
@_spi(AirshipInternal)
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
    /// - Returns: The read result. `itemNotFound` is a genuine missing value;
    ///   any other failure is reported as `error` and must not be treated as missing.
    func readCredentails(
        identifier: String,
        appKey: String
    ) async -> AirshipKeychainReadResult
}

/// Keychain access
/// - Note: For internal use only. :nodoc:
@_spi(AirshipInternal)
public final class AirshipKeychainAccess: AirshipKeychainAccessProtocol {

    public static let shared: AirshipKeychainAccess = AirshipKeychainAccess()

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
    ) async -> AirshipKeychainReadResult {

        let service = service(appKey: appKey)

        return await self.dispatch { [service] in
            AirshipKeychainReadResolver.resolve(
                current: Keychain.readCredentials(
                    identifier: identifier,
                    service: service
                ),
                legacy: {
                    // If we do not have a new value, check
                    // the old service location
                    guard let bundleID = Bundle.main.bundleIdentifier else {
                        return .itemNotFound
                    }

                    let result = Keychain.readCredentials(
                        identifier: identifier,
                        service: bundleID
                    )

                    if case .success(let old) = result {
                        // Migrate old data to new service location
                        let _ = Keychain.writeCredentials(
                            old,
                            identifier: identifier,
                            service: service
                        )
                    }
                    return result
                }
            )
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
    ) -> AirshipKeychainReadResult {
        guard let identifierData = identifier.data(using: .utf8) else {
            AirshipLogger.error("Keychain read failed status:\(errSecParam)")
            return .error(errSecParam)
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
            if status == errSecItemNotFound {
                return .itemNotFound
            }
            AirshipLogger.error("Keychain read failed status:\(status)")
            return .error(status)
        }

        guard let existingItem = item as? [String: Any],
              let credentials = AirshipKeychainItemDecoder.credentials(from: existingItem)
        else {
            // An undecodable item will never become readable. Reporting it as not
            // found lets the caller recreate (and overwrite) it. For the device ID
            // this means a new UUID, so one restore detection is the accepted cost
            // versus an "unknown" ID / missing Message Center user forever.
            AirshipLogger.error("Keychain item could not be decoded, treating as not found")
            return .itemNotFound
        }

        let attrAccessible = existingItem[kSecAttrAccessible as String] as? String
        if attrAccessible != (kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly as String) {
            updateThisDeviceOnly(credentials: credentials, identifier: identifier, service: service)
        }

        return .success(credentials)
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
            AirshipLogger.trace("Updated keychain value to this device only")
        } else {
            AirshipLogger.debug("Failed to update keychain value status:\(updateStatus)")
        }
    }
}

/// Decodes the attributes dictionary returned by `SecItemCopyMatching`.
///
/// An item that exists but cannot be decoded will never become readable, so
/// callers report it as not found; recreating it replaces the bad item
/// (`writeCredentials` deletes any existing item first).
enum AirshipKeychainItemDecoder {
    static func credentials(from item: [String: Any]) -> AirshipKeychainCredentials? {
        guard let passwordData = item[kSecValueData as String] as? Data,
              let password = String(data: passwordData, encoding: .utf8),
              let username = item[kSecAttrAccount as String] as? String
        else {
            return nil
        }
        return AirshipKeychainCredentials(username: username, password: password)
    }
}

/// Decides between the current and legacy service location reads.
enum AirshipKeychainReadResolver {
    /// The legacy location is only consulted when the current one reports
    /// `itemNotFound`. An error on the current location is returned as is, so
    /// a failure is never masked by (or mistaken for) a missing item.
    static func resolve(
        current: AirshipKeychainReadResult,
        legacy: () -> AirshipKeychainReadResult
    ) -> AirshipKeychainReadResult {
        guard case .itemNotFound = current else {
            return current
        }
        return legacy()
    }
}
