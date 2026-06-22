// Copyright Urban Airship and Contributors


public import Foundation
import Combine

import AirshipCore

/// A sort comparator type for ordering message center messages.
public typealias ComparePredicate = any SortComparator<MessageCenterMessage>

/// View model for the message center stories strip.
@MainActor
final class MessageCenterStoriesViewModel: ObservableObject {

    /// The list of messages to display in the stories strip.
    /// Filtered and sorted according to the predicates passed at initialization.
    @Published
    private(set) var stories: [MessageCenterMessage] = []

    /// Whether the view model has finished its initial load.
    /// Set to `true` when the first inbox update is received (or when no message center is available).
    @Published
    private(set) var isLoaded: Bool = false

    private let filterPredicate: (any MessageCenterPredicate)?
    private let sortPredicate: ComparePredicate?

    private let messageCenter: (any MessageCenter)?

    private var updates: Set<AnyCancellable> = []

    /// Creates a view model that observes the message center inbox with optional filter and sort.
    ///
    /// - Parameters:
    ///   - filter: Optional predicate to include only messages that satisfy the condition. Omit for all messages.
    ///   - sort: Optional comparator to order messages. Omit for inbox default order.
    public init(
        filter: (any MessageCenterPredicate)? = nil,
        sort: ComparePredicate? = nil,
    ) {
        
        self.filterPredicate = filter
        self.sortPredicate = sort
        
        if Airship.isFlying {
            self.messageCenter = Airship.messageCenter
        } else {
            self.messageCenter = nil
        }
        
        self.messageCenter?.inbox.messagePublisher
            .receive(on: RunLoop.main)
            .sink { [weak self] incoming in
                guard let self else { return }
                self.objectWillChange.send()

                self.isLoaded = true
                
                var toStore: [MessageCenterMessage] = []
                if let filterPredicate {
                    toStore = incoming.filter(filterPredicate.evaluate)
                }
                
                if let sortPredicate {
                    self.stories = toStore.sorted(using: sortPredicate)
                }

                self.stories = toStore
            }
            .store(in: &self.updates)
    }

    init(previewStories: [MessageCenterMessage]) {
        self.filterPredicate = nil
        self.sortPredicate = nil
        self.messageCenter = nil
        self.stories = previewStories
        self.isLoaded = true
    }
}
