import Foundation
import Combine
@testable import AirshipCore

class TestChannelRegistrar:  ChannelRegistrarProtocol {

    let updatesSubject = PassthroughSubject<ChannelRegistrationUpdate, Never>()
    public var updatesPublisher: AnyPublisher<ChannelRegistrationUpdate, Never> {
        return updatesSubject.eraseToAnyPublisher()
    }

    public var extenders: [(ChannelRegistrationPayload) async -> ChannelRegistrationPayload] = []
    
    public var channelPayload: ChannelRegistrationPayload {
        get async {
            var result: ChannelRegistrationPayload = ChannelRegistrationPayload()

            for extender in extenders {
                result = await extender(result)
            }
            return result
        }
    }

    public func addChannelRegistrationExtender(extender: @escaping (AirshipCore.ChannelRegistrationPayload) async -> AirshipCore.ChannelRegistrationPayload) {
        self.extenders.append(extender)
    }

    public var channelID: String?

    public var registerCalled = false

    public func register(forcefully: Bool) {
        registerCalled = true
    }
}
