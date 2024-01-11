/* Copyright Airship and Contributors */

import Network

#if os(watchOS)
import WatchConnectivity
#endif

/// - Note: For internal use only. :nodoc:
@objc(UANetworkMonitor)
open class NetworkMonitor: NSObject {

    private var pathMonitor: Any?

    @objc
    public var connectionUpdates: ((Bool) -> Void)?

    private var _isConnected = false {
        didSet {
            connectionUpdates?(_isConnected)
        }
    }

    @objc
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

    @objc
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
public protocol NetworkCheckerProtocol: Actor, Sendable {
    var isConnected: Bool { get }
}

/// - Note: For internal use only. :nodoc:
public actor NetworkChecker: NetworkCheckerProtocol {
    private let networkMonitor: NetworkMonitor = NetworkMonitor()
    public init() {}
    public var isConnected: Bool {
        return networkMonitor.isConnected
    }
}


