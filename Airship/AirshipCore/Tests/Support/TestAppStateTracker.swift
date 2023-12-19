import AirshipCore
import Foundation
import Combine

public final class TestAppStateTracker: AppStateTrackerProtocol, @unchecked Sendable {

    private let stateSubject: PassthroughSubject<ApplicationState, Never> = PassthroughSubject()

    public func waitForActive() async {
        guard self.currentState != .active else {
            return
        }
        
        var subscription: AnyCancellable?
        await withCheckedContinuation { continuation in
            subscription = stateSubject.eraseToAnyPublisher()
                .filter { $0 == .active }
                .first()
                .sink { _ in
                    continuation.resume()
                }
        }
        subscription?.cancel()
    }
    
    public var state: AirshipCore.ApplicationState { return currentState }
    public var currentState: ApplicationState = .background {
        didSet {
            stateSubject.send(currentState)
        }
    }
}
