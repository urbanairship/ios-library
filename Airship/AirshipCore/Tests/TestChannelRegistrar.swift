import Foundation
import Combine
@testable import AirshipCore

class TestChannelRegistrar:  ChannelRegistrarProtocol, @unchecked Sendable {
    let registrationUpdates: AirshipAsyncChannel<ChannelRegistrationUpdate> = .init()

    var payloadCreateBlock: (@Sendable () async -> AirshipCore.ChannelRegistrationPayload?)?

    private var extenders: [@Sendable (inout ChannelRegistrationPayload) async -> Void] = []

    public var channelPayload: ChannelRegistrationPayload {
        get async {
            let payload = await payloadCreateBlock?()
            var result: ChannelRegistrationPayload = payload ?? ChannelRegistrationPayload()

            for extender in extenders {
                await extender(&result)
            }
            return result
        }
    }

    public func addRegistrationExtender(_ extender: @Sendable @escaping (inout ChannelRegistrationPayload) async -> Void) {
        self.extenders.append(extender)
    }

    public var channelID: String?

    public var registerCalled = false

    public func register(forcefully: Bool) {
        registerCalled = true
    }
}

