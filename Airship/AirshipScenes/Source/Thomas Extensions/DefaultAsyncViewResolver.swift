/* Copyright Airship and Contributors */

@_spi(AirshipInternal) import AirshipSceneRenderer
@_spi(AirshipInternal) import AirshipCore
import Foundation

/// Resolves async-view requests using the SDK's request session, applying app/channel/contact
/// auth. Owns the network + identity work so the renderer doesn't have to.
struct DefaultAsyncViewResolver: AsyncViewResolver {

    @MainActor
    func resolve(url: URL, auth: ThomasAsyncViewAuth) async throws -> Data {
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
