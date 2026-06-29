/* Copyright Airship and Contributors */

public import Foundation

/// Resolves an async-view request to its raw layout payload. Implemented by the host, which
/// owns the network session, auth tokens, and channel/contact identifiers — keeping that
/// "knows about the world" code out of the renderer.
/// - Note: For internal use only. :nodoc:
@_spi(AirshipInternal)
public protocol AsyncViewResolver: Sendable {
    @MainActor
    func resolve(url: URL, auth: ThomasAsyncViewAuth) async throws -> Data
}

/// Auth requirement for an async-view request, neutral to whoever resolves it.
/// - Note: For internal use only. :nodoc:
@_spi(AirshipInternal)
@frozen
public enum ThomasAsyncViewAuth: Sendable, Equatable {
    case app
    case channel
    case contact
    case none
}

/// Error surfaced by an `AsyncViewResolver`. The renderer uses these to drive retry/status.
/// - Note: For internal use only. :nodoc:
@_spi(AirshipInternal)
public enum AsyncViewResolverError: Error, Sendable {
    case client
    case server(statusCode: Int)
    case timedOut
}
