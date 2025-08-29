import AirshipCore
import Foundation

actor TestNetworkChecker: AirshipNetworkCheckerProtocol {
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
