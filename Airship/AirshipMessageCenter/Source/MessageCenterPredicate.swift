/* Copyright Airship and Contributors */

import Foundation
public import SwiftUI
import UIKit

#if canImport(AirshipCore)
import AirshipCore
#endif

public protocol MessageCenterPredicate: Sendable {
    /// Evaluate the message center message. Used to filter the message center list
    /// - Parameters:
    ///     - message: The message center message
    /// - Returns: True if the message passed the evaluation, otherwise false.
    func evaluate(message: MessageCenterMessage) -> Bool
}

// MARK: Message center predicate
extension View {
    /// Overrides the message center predicate
    /// - Parameters:
    ///     - predicate: The message center predicate
    public func messageCenterPredicate(_ predicate: (any MessageCenterPredicate)?) -> some View {
        environment(\.airshipMessageCenterPredicate, predicate)
    }
}

struct MessageCenterPredicateKey: EnvironmentKey {
    static let defaultValue: (any MessageCenterPredicate)? = nil
}

extension EnvironmentValues {
    /// Airship message center predicate environment value
    public var airshipMessageCenterPredicate: (any MessageCenterPredicate)? {
        get { self[MessageCenterPredicateKey.self] }
        set { self[MessageCenterPredicateKey.self] = newValue }
    }
}
