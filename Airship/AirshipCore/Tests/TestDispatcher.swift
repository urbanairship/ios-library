/* Copyright Airship and Contributors */

@testable
import AirshipCore

final class TestDispatcher: UADispatcher {
    func dispatchAsync(_ block: @escaping @Sendable () -> Void) {
        block()
    }
    
    func doSync(_ block: @escaping @Sendable () -> Void) {
        block()
    }
    
    func dispatchAsyncIfNecessary(_ block: @escaping @Sendable () -> Void) {
        block()
    }
}
