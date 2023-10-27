/* Copyright Airship and Contributors */

import Foundation

/// NOTE: For internal use only. :nodoc:
actor RemoteDataProvider: RemoteDataProviderProtocol {


    // Old
    private static let lastRefreshMetadataKey = "remotedata.LAST_REFRESH_METADATA"
    private static let lastRefreshTimeKey = "remotedata.LAST_REFRESH_TIME"
    private static let lastRefreshAppVersionKey = "remotedata.LAST_REFRESH_APP_VERSION"

    private static let maxStaleTime: TimeInterval = 3 * 24 * 60.0 // 3 days

    private let dataStore: PreferenceDataStore
    private let delegate: RemoteDataProviderDelegate
    private let remoteDataStore: RemoteDataStore
    private let date: AirshipDate

    private let sourceName: String
    private let defaultEnabled: Bool

    private var requiresRefresh: Bool = false

    nonisolated var source: RemoteDataSource {
        return self.delegate.source
    }
    
    init(
        dataStore: PreferenceDataStore,
        delegate: RemoteDataProviderDelegate,
        defaultEnabled: Bool = true,
        inMemory: Bool = false,
        date: AirshipDate = AirshipDate.shared
    ) {
        self.dataStore = dataStore
        self.delegate = delegate
        self.defaultEnabled = defaultEnabled
        self.date = date
        self.remoteDataStore = RemoteDataStore(
            storeName: delegate.storeName,
            inMemory: inMemory
        )
        self.sourceName = delegate.source.name

        if (delegate.source == .app) {
            // If we have an old key
            if (self.dataStore.value(forKey: RemoteDataProvider.lastRefreshMetadataKey) != nil) {
                // Remove the old metadata to force an update if the SDK is downgraded
                self.dataStore.removeObject(forKey: RemoteDataProvider.lastRefreshMetadataKey)
                self.dataStore.removeObject(forKey: RemoteDataProvider.lastRefreshTimeKey)
                self.dataStore.removeObject(forKey: RemoteDataProvider.lastRefreshAppVersionKey)

                // This prevents an issue going from 17 -> 16 -> 17 where remote-data is not refreshed
                self.dataStore.removeObject(forKey: "remotedata.\(self.sourceName)_state")
            }

        }
    }

    func payloads(types: [String]) async -> [RemoteDataPayload] {
        guard self.isEnabled else {
            return []
        }
        
        do {
            return try await self.remoteDataStore.fetchRemoteDataFromCache(
                types: types
            )
            .sortedByType(types)
        } catch {
            AirshipLogger.error("Failed to get contact remote data \(error)")
            return []
        }
    }

    func setEnabled(_ enabled: Bool) -> Bool {
        guard enabled != self.isEnabled else {
            return false
        }

        if (!enabled) {
            self.refreshState = nil
        }
        
        self.isEnabled = enabled
        return true
    }

    private var refreshState: LastRefreshState? {
        get {
            self.dataStore.safeCodable(
                forKey: "remotedata.\(self.sourceName)_state"
            )
        }
        set {
            self.dataStore.setSafeCodable(
                newValue,
                forKey: "remotedata.\(self.sourceName)_state"
            )
        }
    }

    private var isEnabled: Bool {
        get {
            self.dataStore.bool(
                forKey: "remotedata.\(self.sourceName)_enabled",
                defaultValue: defaultEnabled
            )
        }
        set {
            self.dataStore.setBool(
                newValue,
                forKey: "remotedata.\(self.sourceName)_enabled"
            )
        }
    }

    func notifyOutdated(remoteDataInfo: RemoteDataInfo) {
        if (self.refreshState?.remoteDataInfo == remoteDataInfo) {
            self.refreshState = nil
        }
    }

    func isCurrent(locale: Locale, randomeValue: Int) async -> Bool {
        guard self.isEnabled else {
            return false
        }

        guard let refreshState = self.refreshState else {
             return false
        }

        return await self.delegate.isRemoteDataInfoUpToDate(
            refreshState.remoteDataInfo,
            locale: locale,
            randomValue: randomeValue
        )
    }

    /// Assumes no reentry
    func refresh(
        changeToken: String,
        locale: Locale,
        randomeValue: Int
    ) async -> RemoteDataRefreshResult {
        AirshipLogger.trace("Checking \(self.sourceName) remote data")

        guard self.isEnabled else {
            do {
                if (try await self.remoteDataStore.hasData()) {
                    try await self.remoteDataStore.clear()
                    return .newData
                }
            } catch {
                AirshipLogger.trace("Failed to clear \(self.sourceName) remote data: \(error)")
                return .failed
            }

            return .skipped
        }

        let refreshState = self.refreshState

        let shouldRefresh = await self.status(
            refreshState: refreshState,
            changeToken: changeToken,
            locale: locale,
            randomeValue: randomeValue
        ) != .upToDate

        guard shouldRefresh else {
            AirshipLogger.trace("Skipping update, \(self.sourceName) remote data already up to date")
            return .skipped
        }

        AirshipLogger.trace("Requesting \(self.sourceName) remote data")

        do {
            let response = try await self.delegate.fetchRemoteData(
                locale: locale,
                randomValue: randomeValue,
                lastRemoteDataInfo: refreshState?.remoteDataInfo
            )

            AirshipLogger.trace("Refresh result for \(self.sourceName) remote data: \(response)")

            guard response.isSuccess || response.statusCode == 304 else {
                return .failed
            }

            if response.isSuccess, let remoteData = response.result {
                try await self.remoteDataStore.overwriteCachedRemoteData(remoteData.payloads)

                self.refreshState = LastRefreshState(
                    changeToken: changeToken,
                    remoteDataInfo: remoteData.remoteDataInfo,
                    date: date.now
                )

                return .newData
            } else {
                guard let refreshState = refreshState else {
                    throw AirshipErrors.error("Received 304 without a last modified time.")
                }

                self.refreshState = LastRefreshState(
                    changeToken: changeToken,
                    remoteDataInfo: refreshState.remoteDataInfo,
                    date: date.now
                )

                return .skipped
            }
            
        } catch {
            AirshipLogger.trace("Refresh failed for \(self.sourceName) remote data: \(error)")
            return .failed
        }
    }

    func status(changeToken: String, locale: Locale, randomeValue: Int) async -> RemoteDataSourceStatus {
        return await status(
            refreshState: self.refreshState,
            changeToken: changeToken,
            locale: locale,
            randomeValue: randomeValue
        )
    }

    private func status(
        refreshState: LastRefreshState?,
        changeToken: String,
        locale: Locale,
        randomeValue: Int
    ) async ->RemoteDataSourceStatus {
        guard 
            self.isEnabled,
            let refreshState = refreshState,
            let refreshDate = refreshState.date,
            self.date.now.timeIntervalSince(refreshDate) <= RemoteDataProvider.maxStaleTime
        else {
            return .outOfDate
        }

        let isUpToDate = await self.delegate.isRemoteDataInfoUpToDate(
            refreshState.remoteDataInfo,
            locale: locale,
            randomValue: randomeValue
        )

        guard isUpToDate else {
            return .outOfDate
        }

        guard changeToken == refreshState.changeToken else {
            return .stale
        }

        return .upToDate
    }
}

fileprivate struct LastRefreshState: Codable {
    let changeToken: String
    let remoteDataInfo: RemoteDataInfo
    let date: Date?
}


fileprivate extension RemoteDataSource {
    var name: String {
        switch(self) {
        case .app: return "app"
        case .contact: return "contact"
        }
    }
}
