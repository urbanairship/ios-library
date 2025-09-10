/* Copyright Airship and Contributors */

import Foundation
import Combine

@MainActor
class ButtonState: ObservableObject {
    let identifier: String
    init(identifier: String) {
        self.identifier = identifier
    }
}
