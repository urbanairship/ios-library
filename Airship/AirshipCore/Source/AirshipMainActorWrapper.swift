/* Copyright Airship and Contributors */

import Foundation


final class AirshipMainActorWrapper<T: Sendable>: @unchecked Sendable {
    @MainActor
    var value: T

    init(_ value: T) {
        self.value = value
    }
}
