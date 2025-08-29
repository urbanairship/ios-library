/* Copyright Airship and Contributors */

import Foundation

@MainActor
class ButtonState: ObservableObject {
    let identifier: String
    init(identifier: String) {
        self.identifier = identifier
    }
}
