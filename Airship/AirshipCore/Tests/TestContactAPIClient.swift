import Foundation

@testable import AirshipCore

class TestContactAPIClient: ContactsAPIClientProtocol {

    var resolveCallback:
        ((String, String?) async throws -> AirshipHTTPResponse<ContactIdentifyResult>)?

    var identifyCallback:
        ((String, String, String?) async throws -> AirshipHTTPResponse<ContactIdentifyResult>)?

    var resetCallback:
        ((String) async throws -> AirshipHTTPResponse<ContactIdentifyResult>)?

    var updateCallback:
        ((String, [TagGroupUpdate]?, [AttributeUpdate]?, [ScopedSubscriptionListUpdate]?) async throws -> AirshipHTTPResponse<Void>)?

    var associateChannelCallback:
        ((String, String, ChannelType) async throws -> AirshipHTTPResponse<AssociatedChannel>)?

    var registerEmailCallback:
        ((String, String, EmailRegistrationOptions, Locale) async throws -> AirshipHTTPResponse<AssociatedChannel>)?

    var registerSMSCallback:
        ((String, String, SMSRegistrationOptions, Locale) async throws -> AirshipHTTPResponse<AssociatedChannel>)?

    var registerOpenCallback:
        ((String, String, OpenRegistrationOptions, Locale) async throws -> AirshipHTTPResponse<AssociatedChannel>)?

    init() {}

    public func resolve(
        channelID: String,
        contactID: String?
    ) async throws -> AirshipHTTPResponse<ContactIdentifyResult> {
        return try await resolveCallback!(channelID, contactID)
    }

    public func identify(
        channelID: String,
        namedUserID: String,
        contactID: String?
    ) async throws -> AirshipHTTPResponse<ContactIdentifyResult> {
        return try await identifyCallback!(channelID, namedUserID, contactID)
    }

    public func reset(
        channelID: String
    ) async throws -> AirshipHTTPResponse<ContactIdentifyResult> {
        return try await resetCallback!(channelID)
    }

    public func update(
        contactID: String,
        tagGroupUpdates: [TagGroupUpdate]?,
        attributeUpdates: [AttributeUpdate]?,
        subscriptionListUpdates: [ScopedSubscriptionListUpdate]?
    ) async throws -> AirshipHTTPResponse<Void> {
        return try await updateCallback!(contactID, tagGroupUpdates, attributeUpdates, subscriptionListUpdates)
    }

    public func associateChannel(
        contactID: String,
        channelID: String,
        channelType: ChannelType
    ) async throws -> AirshipHTTPResponse<AssociatedChannel> {
        return try await associateChannelCallback!(contactID, channelID, channelType)
    }

    public func registerEmail(
        contactID: String,
        address: String,
        options: EmailRegistrationOptions,
        locale: Locale
    ) async throws -> AirshipHTTPResponse<AssociatedChannel> {
        return try await registerEmailCallback!(contactID, address, options, locale)
    }

    public func registerSMS(
        contactID: String,
        msisdn: String,
        options: SMSRegistrationOptions,
        locale: Locale
    ) async throws -> AirshipHTTPResponse<AssociatedChannel> {
        return try await registerSMSCallback!(contactID, msisdn, options, locale)
    }

    public func registerOpen(
        contactID: String,
        address: String,
        options: OpenRegistrationOptions,
        locale: Locale
    ) async throws -> AirshipHTTPResponse<AssociatedChannel> {
        return try await registerOpenCallback!(contactID, address, options, locale)
    }
}
