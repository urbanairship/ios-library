/* Copyright Airship and Contributors */

import Foundation

#if canImport(AirshipCore)
import AirshipCore
#endif

/// Stores information about a remote-data source used for scheduling
final class AutomationSourceInfoStore: Sendable {
    let dataStore: PreferenceDataStore

    init(dataStore: PreferenceDataStore) {
        self.dataStore = dataStore
    }

    private static let sourceInfoKeyPrefix: String = "AutomationSourceInfo"

    func getSourceInfo(source: RemoteDataSource, contactID: String?) -> AutomationSourceInfo? {
        let key = makeInfoKey(source: source, contactID: contactID)

        if let info: AutomationSourceInfo = self.dataStore.safeCodable(forKey: key) {
            return info
        }

        return self.recoverSourceInfo(source: source, contactID: contactID)
    }

    func setSourceInfo(
        _ sourceInfo: AutomationSourceInfo,
        source: RemoteDataSource,
        contactID: String?
    )  {
        let key = makeInfoKey(source: source, contactID: contactID)
        self.dataStore.setSafeCodable(sourceInfo, forKey: key)
    }

    private func makeInfoKey(source: RemoteDataSource, contactID: String?) -> String {
        return if source == .contact {
            "\(Self.sourceInfoKeyPrefix).\(source).\(contactID ?? "")"
        } else {
            "\(Self.sourceInfoKeyPrefix).\(source)"
        }
    }

    private func recoverSourceInfo(source: RemoteDataSource, contactID: String?) -> AutomationSourceInfo? {
        let key = makeInfoKey(source: source, contactID: contactID)

        switch (source) {
        case .app:
            let lastSDKVersion = self.dataStore.string(forKey: LegacyAppKeys.lastSDKVersion)
            let lastPayloadTimestamp = self.dataStore.object(forKey: LegacyAppKeys.lastPayloadTimestamp)

            defer {
                self.dataStore.removeObject(forKey: LegacyAppKeys.lastMetadata)
                self.dataStore.removeObject(forKey: LegacyAppKeys.lastPayloadTimestamp)
                self.dataStore.removeObject(forKey: LegacyAppKeys.lastRemoteDataInfo)
                self.dataStore.removeObject(forKey: LegacyAppKeys.lastSDKVersion)
            }

            guard let lastPayloadTimestamp = lastPayloadTimestamp as? Date else {
                return nil
            }

            let sourceInfo = AutomationSourceInfo(
                remoteDataInfo: nil,
                payloadTimestamp: lastPayloadTimestamp,
                airshipSDKVersion: lastSDKVersion
            )
            self.dataStore.setSafeCodable(sourceInfo, forKey: key)
            return sourceInfo

        case .contact:
            let lastSDKVersion = self.dataStore.string(forKey: LegacyContactKeys.lastSDKVersion(contactID))
            let lastPayloadTimestamp = self.dataStore.object(forKey: LegacyContactKeys.lastPayloadTimestamp(contactID))

            defer {
                self.dataStore.removeObject(forKey: LegacyContactKeys.lastPayloadTimestamp(contactID))
                self.dataStore.removeObject(forKey: LegacyContactKeys.lastRemoteDataInfo(contactID))
                self.dataStore.removeObject(forKey: LegacyContactKeys.lastSDKVersion(contactID))
            }

            guard let lastPayloadTimestamp = lastPayloadTimestamp as? Date else {
                return nil
            }

            let sourceInfo = AutomationSourceInfo(
                remoteDataInfo: nil,
                payloadTimestamp: lastPayloadTimestamp,
                airshipSDKVersion: lastSDKVersion
            )
            self.dataStore.setSafeCodable(sourceInfo, forKey: key)
            return sourceInfo
#if canImport(AirshipCore)
        @unknown default:
            return nil
#endif
        }
    }
}

struct AutomationSourceInfo: Sendable, Codable, Equatable {
    let remoteDataInfo: RemoteDataInfo?
    let payloadTimestamp: Date
    let airshipSDKVersion: String?
}

fileprivate struct LegacyAppKeys {
    static let lastPayloadTimestamp = "UAInAppRemoteDataClient.LastPayloadTimeStamp"
    static let lastSDKVersion = "UAInAppRemoteDataClient.LastSDKVersion"
    static let lastRemoteDataInfo = "UAInAppRemoteDataClient.LastRemoteDataInfo"
    static let lastMetadata = "UAInAppRemoteDataClient.LastPayloadMetadata"
}

fileprivate struct LegacyContactKeys {
    private static let lastPayloadTimestampPrefix = "UAInAppRemoteDataClient.LastPayloadTimeStamp.Contact"
    private static let lastSDKVersionPrefix = "UAInAppRemoteDataClient.LastSDKVersion.Contact"
    private static let lastRemoteDataInfoPrefix = "UAInAppRemoteDataClient.LastRemoteDataInfo.Contact"

    static func lastPayloadTimestamp(_ contactID: String?) -> String {
        return "\(lastPayloadTimestampPrefix)\(contactID ?? "")"
    }

    static func lastSDKVersion(_ contactID: String?) -> String {
        return "\(lastSDKVersionPrefix)\(contactID ?? "")"
    }

    static func lastRemoteDataInfo(_ contactID: String?) -> String {
        return "\(lastRemoteDataInfoPrefix)\(contactID ?? "")"

    }
}
