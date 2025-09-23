/* Copyright Airship and Contributors */

import Combine
import Foundation

@MainActor
final class Toast: ObservableObject {
    struct Message: Equatable, Sendable, Hashable {
        let id: String = UUID().uuidString
        let text: String
        let duration: TimeInterval
    }

    @Published
    var message: Message?
}
