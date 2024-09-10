import AirshipCore
import Foundation
import Combine

public final class TestAppStateTracker: AppStateTrackerProtocol, @unchecked Sendable {
    private let stateValue: AirshipMainActorValue<ApplicationState> = AirshipMainActorValue(.background)

    public var stateUpdates: AsyncStream<ApplicationState> {
        stateValue.updates
    }


    private let stateSubject: PassthroughSubject<ApplicationState, Never> = PassthroughSubject()

    @MainActor
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
    @MainActor
    public var currentState: ApplicationState = .background {
        didSet {
            stateSubject.send(currentState)
            stateValue.set(currentState)
        }
    }


    @MainActor
    public func updateState(_ state: ApplicationState) async {
        self.currentState = state
    }
}
