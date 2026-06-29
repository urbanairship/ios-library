/* Copyright Airship and Contributors */

public import Foundation


/// Resolves WKWebView authentication challenges. Implemented by the host so the renderer doesn't
/// depend on the SDK's challenge-resolution machinery (server-trust pinning, etc.).
/// - Note: For internal use only. :nodoc:
@_spi(AirshipInternal)
public protocol AirshipWebViewChallengeResolver: Sendable {
    func resolve(
        _ challenge: URLAuthenticationChallenge
    ) async -> (URLSession.AuthChallengeDisposition, URLCredential?)
}
