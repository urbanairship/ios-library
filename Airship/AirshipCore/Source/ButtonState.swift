/* Copyright Airship and Contributors */

import Foundation

@available(iOS 13.0.0, tvOS 13.0, *)
class ButtonState: ObservableObject {
    let identifier: String
    init(identifier: String) {
        self.identifier = identifier
    }
}
