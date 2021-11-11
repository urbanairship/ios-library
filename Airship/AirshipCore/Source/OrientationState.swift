/* Copyright Airship and Contributors */

import Foundation

@available(iOS 13.0.0, tvOS 13.0, *)
class OrientationState: ObservableObject {
    @Published var orientation: Orientation?
    
    init(orientation: Orientation? = nil) {
        self.orientation = orientation
    }
}

