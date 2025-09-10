/* Copyright Airship and Contributors */

import Combine
import Foundation

#if canImport(AirshipCore)
import AirshipCore
#endif

@MainActor
class MessageCenterListItemViewModel: ObservableObject {

    private var cancellables = Set<AnyCancellable>()

    @Published
    private(set) public var message: MessageCenterMessage

    public init(message: MessageCenterMessage) {

        self.message = message
        Airship.messageCenter.inbox
            .messagePublisher
            .compactMap({ messages in
                messages.filter { $0.id == message.id }.first
            })
            .removeDuplicates()
            .receive(on: RunLoop.main)
            .sink { message in
                self.message = message
            }
            .store(in: &self.cancellables)
    }
}
