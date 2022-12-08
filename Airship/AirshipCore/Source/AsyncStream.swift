/* Copyright Airship and Contributors */

import Foundation

extension AsyncStream {
    static func makeStreamWithContinuation(
        _ type: Element.Type = Element.self
    ) -> (Self, AsyncStream.Continuation) {
        var escapee: Continuation!
        let stream = Self(type) { continuation in
            escapee = continuation
        }
        return (stream, escapee)
    }
}
