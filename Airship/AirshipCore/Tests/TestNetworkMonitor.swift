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
    init() {}

    public func setConnected(_ connected: Bool) {
        self.isConnected = connected
    }
    private(set) var isConnected: Bool = false

}
