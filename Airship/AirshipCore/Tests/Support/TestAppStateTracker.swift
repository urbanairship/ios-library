import AirshipCore
import Foundation

public final class TestAppStateTracker: AppStateTrackerProtocol, @unchecked Sendable {
    public var state: AirshipCore.ApplicationState { return currentState }
    public var currentState: ApplicationState = .background
}
