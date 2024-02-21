import Foundation


protocol SessionEventFactoryProtocol: Sendable {
    @MainActor
    func make(event: SessionEvent) -> AirshipEvent
}

struct SessionEventFactory: SessionEventFactoryProtocol {

    let push: @Sendable () -> AirshipPushProtocol

    init(push: @escaping @Sendable () -> AirshipPushProtocol = Airship.componentSupplier()) {
        self.push = push
    }

    @MainActor
    func make(event: SessionEvent) -> AirshipEvent {
        AirshipEvents.sessionEvent(sessionEvent: event, push: self.push())
    }
}

