/* Copyright Airship and Contributors */

import Foundation

public extension AsyncStream {
    static func airshipMakeStreamWithContinuation(
        _ type: Element.Type = Element.self
    ) -> (Self, AsyncStream.Continuation) {
        var escapee: Continuation!
        let stream = Self(type) { continuation in
            escapee = continuation
        }
        return (stream, escapee)
    }
}
