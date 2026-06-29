/* Copyright Airship and Contributors */

@_spi(AirshipInternal) import AirshipSceneRenderer
@_spi(AirshipInternal) import AirshipCore
public import AirshipBasement

public import Foundation

/// Resolves async-view requests using the SDK's request session, applying app/channel/contact
/// auth. Owns the network + identity work so the renderer doesn't have to.
/// - Note: For internal use only. :nodoc:
@_spi(AirshipInternal)
public struct DefaultAsyncViewResolver: AsyncViewResolver {
    public init() {}

    @MainActor
    public func resolve(url: URL, auth: ThomasAsyncViewAuth) async throws -> Data {
        let resolvedAuth: AirshipRequestAuth?
        switch auth {
        case .app:
            resolvedAuth = .generatedAppToken
        case .channel:
            resolvedAuth = .generatedChannelToken(identifier: try await channelID())
        case .contact:
            resolvedAuth = .contactAuthToken(identifier: await contactID())
        case .none:
            resolvedAuth = nil
        }

        let request = AirshipRequest(url: url, method: "GET", auth: resolvedAuth)

        let response: AirshipHTTPResponse<Data> = try await Airship.config.requestSession.performHTTPRequest(request) { data, response in
            guard let data, (200...299).contains(response.statusCode) else {
                throw AsyncViewResolverError.server(statusCode: response.statusCode)
            }
            return data
        }

        guard let body = response.result else {
            throw AsyncViewResolverError.client
        }
        return body
    }

    @MainActor
    private func channelID() async throws -> String {
        var iterator = Airship.channel.identifierUpdates.makeAsyncIterator()
        guard let channelID = await iterator.next() else {
            throw AsyncViewResolverError.client
        }
        return channelID
    }

    @MainActor
    private func contactID() async -> String {
        await Airship.contact.getStableContactID()
    }
}

/// The Thomas extensions the SDK wires up by default — currently the async-view resolver backed
/// by the real request session. Hosts pass this into the renderer so async views resolve for real.
/// - Note: For internal use only. :nodoc:
@_spi(AirshipInternal)
public struct DefaultThomasExtensions: ThomasExtensions {
    public let asyncViewResolver: (any AsyncViewResolver) = DefaultAsyncViewResolver()
    public let webViewChallengeResolver: (any AirshipWebViewChallengeResolver) = DefaultWebViewChallengeResolver()
    public var inputValidator: (any AirshipInputValidation.Validator)? {
        Airship.isFlying ? Airship.inputValidator : nil
    }
    public init() {}
}

/// Wraps the SDK's `ChallengeResolver` so the renderer doesn't reference it directly.
struct DefaultWebViewChallengeResolver: AirshipWebViewChallengeResolver {
    func resolve(
        _ challenge: URLAuthenticationChallenge
    ) async -> (URLSession.AuthChallengeDisposition, URLCredential?) {
        await ChallengeResolver.shared.resolve(challenge)
    }
}
