/* Copyright Urban Airship and Contributors */

import Combine
import Foundation

#if canImport(AirshipCore)
import AirshipCore
#endif

class MessageCenterListItemViewModel: ObservableObject {

    private var cancellables = Set<AnyCancellable>()

    @Published
    private(set) public var message: MessageCenterMessage

    public init(message: MessageCenterMessage) {

        self.message = message
        MessageCenter.shared.inbox
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
