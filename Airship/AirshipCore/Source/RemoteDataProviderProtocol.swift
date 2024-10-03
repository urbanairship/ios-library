/* Copyright Airship and Contributors */

import Foundation

/// Remote data provider protocol
protocol RemoteDataProviderProtocol: Actor {

    /// The remote-data source.
    nonisolated var source: RemoteDataSource { get }

    /// Gets the payloads from remote-data.
    /// - Parameter types: The payload types.
    /// - Returns An array of payloads.
    func payloads(types: [String]) async -> [RemoteDataPayload]

    /// Notifies that the remote-data info is outdated. This will cause the next refresh to
    /// to fetch data.
    /// - Parameter remoteDataInfo: The remote data info.
    /// - Returns true if cleared, otherwise false.
    func notifyOutdated(remoteDataInfo: RemoteDataInfo) -> Bool

    /// Checks if the source is current.
    /// - Parameter locale: The current locale.
    /// - Parameter randomeValue: The remote-data random value.
    func isCurrent(locale: Locale, randomeValue: Int) async -> Bool


    /// Checks if the source update status.
    /// - Parameter changeToken: The change token.
    /// - Parameter locale: The current locale.
    /// - Parameter randomeValue: The remote-data random value.
    /// - Returns The update status.
    func status(changeToken: String, locale: Locale, randomeValue: Int) async -> RemoteDataSourceStatus


    /// Refreshes remote data
    /// - Parameter changeToken: The change token. Used to control checking for a refresh
    /// even if the remote data info is up to date.
    /// - Parameter locale: The current locale.
    /// - Parameter randomeValue: The remote-data random value.
    /// - Returns true if the value changed, false if not.
    func refresh(
        changeToken: String,
        locale: Locale,
        randomeValue: Int
    ) async -> RemoteDataRefreshResult

    /// Enables/Disables the provider.
    /// - Parameter enabled: true to enable, false to disable
    /// - Returns true if the value changed, false if not.
    func setEnabled(_ enabled: Bool) -> Bool
}

/// Refresh result
enum RemoteDataRefreshResult: Equatable, Sendable {
    /// Refresh was skipped either because it was disabled or data is up to date.
    case skipped

    /// Source was refreshed with new data.
    case newData

    // Refresh failed.
    case failed
}
