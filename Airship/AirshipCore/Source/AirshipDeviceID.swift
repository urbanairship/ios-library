/* Copyright Airship and Contributors */

import Foundation
@_spi(AirshipInternal) import AirshipBasement

protocol AirshipDeviceIDProtocol: Actor {
    var value: String { get async }
}

/**
 * Access to a generated UUID stored in the keychain for this device only. Used to detect app restore only.
 */
actor AirshipDeviceID: AirshipDeviceIDProtocol {
    private static let deviceKeychainID: String = "com.urbanairship.deviceID"

    /// Sentinel returned when the device ID cannot be read or persisted.
    /// Must never be cached or written to the preference store — a restore
    /// decision must not be made from an unpersistable ID.
    nonisolated static let unknownValue: String = "unknown"

    private var cached: String? = nil
    private let keychain: any AirshipKeychainAccessProtocol
    private var queue: AirshipSerialQueue = AirshipSerialQueue()
    private let appKey: String

    init(
        appKey: String,
        keychain: any AirshipKeychainAccessProtocol = AirshipKeychainAccess.shared
    ) {
        self.appKey = appKey
        self.keychain = keychain
    }

    var value: String {
        get async {
            return await queue.runSafe {
                if let cached = await self.cached {
                    return cached
                }

                switch await self.keychain.readCredentails(
                    identifier: AirshipDeviceID.deviceKeychainID,
                    appKey: self.appKey
                ) {
                case .success(let fromKeychain):
                    await self.cacheDeviceId(fromKeychain.password)
                    return fromKeychain.password
                case .itemNotFound:
                    return await self.mintDeviceID()
                case .error(let status):
                    AirshipLogger.error(
                        "Failed to read device ID from the keychain status:\(status)"
                    )
                    return AirshipDeviceID.unknownValue
                }
            }
        }
    }

    private func mintDeviceID() async -> String {
        let deviceID = UUID().uuidString
        let result = await self.keychain.writeCredentials(
            AirshipKeychainCredentials(username: "airship", password: deviceID),
            identifier: AirshipDeviceID.deviceKeychainID,
            appKey: self.appKey
        )
        guard result else {
            AirshipLogger.error("Failed to write device ID to the keychain")
            return AirshipDeviceID.unknownValue
        }
        cacheDeviceId(deviceID)
        return deviceID
    }

    private func cacheDeviceId(_ deviceID: String) {
        self.cached = deviceID
    }
}
