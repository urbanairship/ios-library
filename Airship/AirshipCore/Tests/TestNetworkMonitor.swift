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
