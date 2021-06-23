import Foundation
import AirshipCore

@objc(UATestAppStateTracker)
public class TestAppStateTracker : UAAppStateTracker {

    @objc
    public var currentState : UAApplicationState = .background

    public override var state: UAApplicationState {
        return currentState
    }
}
