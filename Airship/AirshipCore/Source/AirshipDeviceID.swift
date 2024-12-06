/* Copyright Airship and Contributors */

import Foundation

protocol AirshipDeviceIDProtocol: Actor {
    var value: String { get async }
}

/**
 * Access to a generated UUID stored in the keychain for this device only. Used to detect app restore only.
 */
actor AirshipDeviceID: AirshipDeviceIDProtocol {
    private static let deviceKeychainID = "com.urbanairship.deviceID"
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
                } else if let fromKeychain = await self.keychain.readCredentails(
                    identifier: AirshipDeviceID.deviceKeychainID,
                    appKey: self.appKey
                ) {
                    await self.cacheDeviceId(fromKeychain.password)
                    return fromKeychain.password
                } else {
                    let deviceID = UUID().uuidString
                    await self.cacheDeviceId(deviceID)
                    let result = await self.keychain.writeCredentials(
                        AirshipKeychainCredentials(username: "airship", password: deviceID),
                        identifier: AirshipDeviceID.deviceKeychainID,
                        appKey: self.appKey
                    )
                    if (!result) {
                        AirshipLogger.error("Failed to device ID to the keychain")
                    }
                    return deviceID
                }
            }
        }
    }

    private func cacheDeviceId(_ deviceID: String) {
        self.cached = deviceID
    }
}
