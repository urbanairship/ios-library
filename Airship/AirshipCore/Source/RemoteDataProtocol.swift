/* Copyright Airship and Contributors */

import Combine

// NOTE: For internal use only. :nodoc:
public protocol RemoteDataProtocol: AnyObject, Sendable {
    /// Gets the update status for the given source
    /// - Parameter source: The source.
    /// - Returns The status of the source.
    func status(source: RemoteDataSource) async -> RemoteDataSourceStatus

    /// Checks if the remote data info is current or not.
    /// - Parameter remoteDataInfo: The remote data info.
    /// - Returns `true` if current, otherwise `false`.
    func isCurrent(remoteDataInfo: RemoteDataInfo) async -> Bool

    func notifyOutdated(remoteDataInfo: RemoteDataInfo) async
    func publisher(types: [String]) -> AnyPublisher<[RemoteDataPayload], Never>
    func payloads(types: [String]) async -> [RemoteDataPayload]

    func waitRefresh(source: RemoteDataSource, maxTime: TimeInterval?) async
    func waitRefreshAttempt(source: RemoteDataSource, maxTime: TimeInterval?) async
    func waitRefresh(source: RemoteDataSource) async
    func waitRefreshAttempt(source: RemoteDataSource) async

    @discardableResult
    func refresh() async -> Bool

    @discardableResult
    func refresh(source: RemoteDataSource) async -> Bool

    var remoteDataRefreshInterval: TimeInterval { get set }
    func setContactSourceEnabled(enabled: Bool)
}
