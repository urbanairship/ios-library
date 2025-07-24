/* Copyright Airship and Contributors */

import Network

/// - Note: For internal use only. :nodoc:
public protocol AirshipNetworkCheckerProtocol: Sendable {
    @MainActor
    var isConnected: Bool { get }

    @MainActor
    var connectionUpdates: AsyncStream<Bool> { get }
}

#if os(watchOS)

import WatchConnectivity

/// - Note: For internal use only. :nodoc:
public final class AirshipNetworkChecker: AirshipNetworkCheckerProtocol, Sendable {
    private let _isConnected: AirshipMainActorValue<Bool>

    @MainActor
    public var connectionUpdates: AsyncStream<Bool> {
        _isConnected.updates
    }

    @MainActor
    public var isConnected: Bool {
        return _isConnected.value
    }

    public init() {
        self._isConnected = AirshipMainActorValue(true)
    }
}
#else
/// - Note: For internal use only. :nodoc:
public final class AirshipNetworkChecker: AirshipNetworkCheckerProtocol, Sendable {
    private let pathMonitor: NWPathMonitor
    private let _isConnected: AirshipMainActorValue<Bool>
    private let updateQueue: AirshipAsyncSerialQueue = AirshipAsyncSerialQueue()

    @MainActor
    public var connectionUpdates: AsyncStream<Bool> {
        _isConnected.updates
    }

    public static let shared: AirshipNetworkChecker = AirshipNetworkChecker()

    @MainActor
    public var isConnected: Bool {
        return _isConnected.value
    }

    public init() {
        self._isConnected = AirshipMainActorValue(
            AirshipUtils.hasNetworkConnection()
        )

        let monitor = NWPathMonitor()
        self.pathMonitor = monitor

        monitor.pathUpdateHandler = { [updateQueue, _isConnected] path in
            updateQueue.enqueue {
                let connected = path.status == .satisfied
                if await (_isConnected.value != connected) {
                    await _isConnected.set(path.status == .satisfied)
                }
            }
        }

        monitor.start(queue: DispatchQueue.global(qos: .utility))
    }
}

#endif
