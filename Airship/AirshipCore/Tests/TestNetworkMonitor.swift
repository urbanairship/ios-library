import Foundation
import AirshipCore

@objc(UATestNetworkMonitor)
public class TestNetworkMonitor : NetworkMonitor {

    @objc
    public var isConnectedOverride: Bool {
        didSet {
            self.connectionUpdates?(isConnected)
        }
    }
    
    @objc
    open override var isConnected: Bool {
        get {
            return self.isConnectedOverride
        }
    }

    public override init() {
        self.isConnectedOverride = false
        super.init()
    }
}
