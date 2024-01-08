/* Copyright Airship and Contributors */

import Foundation


public final class AirshipMainActorWrapper<T>: @unchecked Sendable {
    @MainActor
    public var value: T

    public init(_ value: T) {
        self.value = value
    }
}
