/* Copyright Airship and Contributors */

public import Combine


/// NOTE: For internal use only. :nodoc:
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

    /// Waits for a successful refresh
    /// - Parameters:
    ///     - source: The remote data source.
    ///     - maxTime: The max time to wait
    func waitRefresh(source: RemoteDataSource, maxTime: TimeInterval?) async

    /// Waits for a successful refresh
    /// - Parameters:
    ///     - source: The remote data source.
    func waitRefresh(source: RemoteDataSource) async

    /// Waits for a refresh attempt for the session.
    /// - Parameters:
    ///     - source: The remote data source.
    ///     - maxTime: The max time to wait
    func waitRefreshAttempt(source: RemoteDataSource, maxTime: TimeInterval?) async

    /// Waits for a refresh attempt for the session.
    /// - Parameters:
    ///     - source: The remote data source.
    func waitRefreshAttempt(source: RemoteDataSource) async

    /// Forces a refresh attempt. This should generally never be called externally. Currently being exposed for
    /// test apps.
    func forceRefresh() async
    
    /// Gets the status updates using the given mapping.
    /// - Returns:a stream of status updates.
    func statusUpdates<T:Sendable>(sources: [RemoteDataSource], map: @escaping (@Sendable (_ statuses: [RemoteDataSource: RemoteDataSourceStatus]) -> T)) async -> AsyncStream<T> 

}
