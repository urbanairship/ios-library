/* Copyright Airship and Contributors */

import Foundation

@MainActor

final class AirshipUnsafeSendableWrapper<T>: @unchecked Sendable {
    var value: T
    init(_ value: T) {
        self.value = value
    }
}
