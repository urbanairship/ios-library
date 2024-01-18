import AirshipCore
import Foundation

@objc(UATestNetworkMonitor)
public class TestNetworkMonitor: NetworkMonitor {

    @objc
    public var isConnectedOverride: Bool {
        didSet {
            self.connectionUpdates?(isConnected)
        }
    }

    @objc
    open override var isConnected: Bool {
        return self.isConnectedOverride
    }

    public override init() {
        self.isConnectedOverride = false
        super.init()
    }
}


actor TestNetworkChecker: NetworkCheckerProtocol {
    private let _isConnected = AirshipMainActorValue(false)

    @MainActor
    var connectionUpdates: AsyncStream<Bool> {
        return _isConnected.updates
    }

    init() {}

    @MainActor
    public func setConnected(_ connected: Bool) {
        self._isConnected.set(connected)
    }

    @MainActor
    var isConnected: Bool {
        return _isConnected.value
    }

}
