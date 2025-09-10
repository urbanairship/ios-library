/* Copyright Airship and Contributors */

import SwiftUI
public import Combine

#if canImport(AirshipCore)
import AirshipCore
#endif

/// The message center controller's possible states.
public enum MessageCenterState: Equatable, Sendable {
    /// The message center is visible, with an optional message ID.
    case visible(messageID: String?)
    /// The message center is not visible.
    case notVisible
}

/// Controller for the Message Center.
@MainActor
public class MessageCenterController: ObservableObject {

    /// The routes available in the message center.
    public enum Route: Sendable, Hashable {
        /// The message route, with the message ID.
        case message(String)
    }

    @Published
    var visibleMessageID: String? = nil

    @Published
    var isMessageCenterVisible: Bool = false

    /// The navigation path.
    @Published
    public var path: [Route] = []

    private var subscriptions: Set<AnyCancellable> = Set()

    private let updateSubject = PassthroughSubject<MessageCenterState, Never>()

    /// Publisher that emits the message center state.
    public var statePublisher: AnyPublisher<MessageCenterState, Never> {
        self.updateSubject
            .removeDuplicates()
            .eraseToAnyPublisher()
    }

    /// Navigates to a message.
    /// - Parameters:
    ///     - messageID: The message ID to navigate to. A `nil` value will pop to the root view.
    public func navigate(messageID: String?) {
        guard self.currentMessageID != messageID else {
            return
        }
        guard let messageID else {
            self.path = []
            return
        }
        self.path = [.message(messageID)]
    }

    var currentMessageID: String? {
        guard case .message(let messageID) = self.path.last else {
            return nil
        }
        return messageID
    }

    /// Default initializer.
    public init() {
        Publishers
            .CombineLatest($visibleMessageID, $isMessageCenterVisible)
            .sink {[updateSubject] (visibleMessageID, isMessageCenterVisible) in
                if  let messageID = visibleMessageID {
                    updateSubject.send(.visible(messageID: messageID))
                } else if isMessageCenterVisible {
                    updateSubject.send(.visible(messageID: nil))
                } else {
                    updateSubject.send(.notVisible)
                }
            }
            .store(in: &subscriptions)
    }
}
