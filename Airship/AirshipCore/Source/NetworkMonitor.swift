/* Copyright Airship and Contributors */

import Network

#if os(watchOS)
import WatchConnectivity
#endif

/// - Note: For internal use only. :nodoc:
open class NetworkMonitor: NSObject {

    private var pathMonitor: Any?

    public var connectionUpdates: ((Bool) -> Void)?

    private var _isConnected = false {
        didSet {
            connectionUpdates?(_isConnected)
        }
    }

    open var isConnected: Bool {
        #if !os(watchOS)
        guard #available(iOS 12.0, tvOS 12.0, *) else {
            return AirshipUtils.connectionType() != ConnectionType.none
        }
        return _isConnected
        #else
        return true
        #endif
    }

    public override init() {
        super.init()
        if #available(iOS 12.0, tvOS 12.0, *) {
            let monitor = NWPathMonitor()
            monitor.pathUpdateHandler = { path in
                self._isConnected = (path.status == .satisfied)
            }

            monitor.start(queue: DispatchQueue.main)
            self.pathMonitor = monitor
        }
    }
}

/// - Note: For internal use only. :nodoc:
public protocol NetworkCheckerProtocol: Sendable {
    @MainActor
    var isConnected: Bool { get }

    @MainActor
    var connectionUpdates: AsyncStream<Bool> { get }
}

#if os(watchOS)
/// - Note: For internal use only. :nodoc:
public final class NetworkChecker: NetworkCheckerProtocol, Sendable {
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
public final class NetworkChecker: NetworkCheckerProtocol, Sendable {
    private let pathMonitor: NWPathMonitor
    private let _isConnected: AirshipMainActorValue<Bool>
    private let updateQueue: AirshipAsyncSerialQueue = AirshipAsyncSerialQueue()

    @MainActor
    public var connectionUpdates: AsyncStream<Bool> {
        _isConnected.updates
    }

    @MainActor
    public var isConnected: Bool {
        return _isConnected.value
    }

    public init() {
        self._isConnected = AirshipMainActorValue(
            AirshipUtils.connectionType() != ConnectionType.none
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
