/* Copyright Airship and Contributors */

import Foundation
import Observation
@_spi(AirshipImport) import AirshipCore

/// Bridges Observation-tracked availability into an `AsyncStream`.
///
/// FoundationModels' model types are `@Observable`, so this is how availability changes
/// (a model finishing its download, Apple Intelligence being toggled in Settings, Private
/// Cloud Compute becoming reachable) reach `AirshipAI.ModelProtocol.availabilityUpdates`.
@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, visionOS 1.0, *)
enum AvailabilityObservation {

    /// Lifetime flag for an observation chain, flipped when the stream is torn down so the
    /// self-re-arming `withObservationTracking` loop stops.
    @MainActor
    private final class Token {
        var isCancelled = false
    }

    /// Streams `read()` under observation tracking, emitting the current value immediately
    /// and re-emitting on every change to the `@Observable` state `read` touches.
    static func stream(
        read: @escaping @MainActor @Sendable () -> AirshipAI.Availability
    ) -> AsyncStream<AirshipAI.Availability> {
        AsyncStream { continuation in
            let token = Token()
            Task { @MainActor in
                observe(token: token, read: read, continuation: continuation)
            }
            continuation.onTermination = { _ in
                Task { @MainActor in token.isCancelled = true }
            }
        }
    }

    /// Reads the current availability under observation tracking and yields it, then
    /// re-arms itself when the tracked value changes. A no-op once `token` is cancelled.
    @MainActor
    private static func observe(
        token: Token,
        read: @escaping @MainActor @Sendable () -> AirshipAI.Availability,
        continuation: AsyncStream<AirshipAI.Availability>.Continuation
    ) {
        guard !token.isCancelled else { return }

        let current = withObservationTracking {
            read()
        } onChange: {
            // Fires just before the value changes; re-read on the next hop so we
            // observe the new value and re-establish tracking.
            Task { @MainActor in
                observe(token: token, read: read, continuation: continuation)
            }
        }
        continuation.yield(current)
    }
}
