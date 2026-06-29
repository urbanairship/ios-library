/* Copyright Airship and Contributors */

@_spi(AirshipInternal) import AirshipSceneRenderer
@_spi(AirshipInternal) import AirshipCore
import Foundation

/// Wraps the SDK's `ChallengeResolver` so the renderer doesn't reference it directly.
struct DefaultWebViewChallengeResolver: AirshipWebViewChallengeResolver {
    func resolve(
        _ challenge: URLAuthenticationChallenge
    ) async -> (URLSession.AuthChallengeDisposition, URLCredential?) {
        await ChallengeResolver.shared.resolve(challenge)
    }
}
