/* Copyright Urban Airship and Contributors */

import SwiftUI
import Combine

#if canImport(AirshipCore)
import AirshipCore
#endif

/// The message center controller possible states
public enum MessageCenterState: Equatable {
    case visible(messageID: String?)
    case notVisible
}

/// Controller for the Message Center View.
@objc(UAMessageCenterController)
public class MessageCenterController: NSObject, ObservableObject {
    
    @Published
    private(set) var visibleMessageID: String? = nil
    
    @Published
    private var isMessageCenterVisible: Bool = false
    
    private var subscriptions: Set<AnyCancellable> = Set()
    
    private let updateSubject = PassthroughSubject<MessageCenterState, Never>()
    
    func displayMessageCenter(_ display: Bool) {
        self.isMessageCenterVisible = display
    }
    
    func displayMessage(_ messageId: String?) {
        self.visibleMessageID = messageId
    }
    
    /// Publisher that emits the message center state.
    public var statePublisher: AnyPublisher<MessageCenterState, Never> {
        self.updateSubject
            .removeDuplicates()
            .eraseToAnyPublisher()
    }
    
    /// Navigates to the message ID.
    /// - Parameters:
    ///     - messageID: The message ID to navigate to.
    @objc
    public func navigate(messageID: String?) {
        self.displayMessage(messageID)
    }
    
    @objc
    public override init() {
        super.init()
        Publishers
            .CombineLatest($visibleMessageID, $isMessageCenterVisible)
            .sink {(visibleMessageID, isMessageCenterVisible) in
                if  let messageID = visibleMessageID {
                    self.updateSubject.send(.visible(messageID: messageID))
                } else if isMessageCenterVisible {
                    self.updateSubject.send(.visible(messageID: nil))
                } else {
                    self.updateSubject.send(.notVisible)
                }
            }
            .store(in: &subscriptions)
    }
}
