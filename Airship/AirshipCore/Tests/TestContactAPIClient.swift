import Foundation

@testable import AirshipCore

class TestContactAPIClient: ContactsAPIClientProtocol, @unchecked Sendable {
    var resolveCallback:
    ((String, String?, String?) async throws -> AirshipHTTPResponse<ContactIdentifyResult>)?

    var identifyCallback:
    ((String, String, String?, String?) async throws -> AirshipHTTPResponse<ContactIdentifyResult>)?

    var resetCallback:
    ((String, String?) async throws -> AirshipHTTPResponse<ContactIdentifyResult>)?

    var resendCallback:
    ((ResendOptions) async throws -> AirshipHTTPResponse<Bool>)?

    var updateCallback:
    ((String, [TagGroupUpdate]?, [AttributeUpdate]?, [ScopedSubscriptionListUpdate]?) async throws -> AirshipHTTPResponse<Void>)?

    var associateChannelCallback:
    ((String, String, ChannelType) async throws -> AirshipHTTPResponse<ContactAssociateChannelResult>)?

    var disassociateChannelCallback:
    ((Bool, String, ChannelType) async throws -> AirshipHTTPResponse<ContactDisassociateChannelResult>)?

    var disassociateEmailCallback:
    ((Bool, String, String) async throws -> AirshipHTTPResponse<ContactDisassociateChannelResult>)?

    var disassociateSMSCallback:
    ((Bool, String, String, String) async throws -> AirshipHTTPResponse<ContactDisassociateChannelResult>)?

    var registerEmailCallback:
    ((String, String, EmailRegistrationOptions, Locale) async throws -> AirshipHTTPResponse<ContactAssociateChannelResult>)?

    var registerSMSCallback:
    ((String, String, SMSRegistrationOptions, Locale) async throws -> AirshipHTTPResponse<ContactAssociateChannelResult>)?

    var registerOpenCallback:
    ((String, String, OpenRegistrationOptions, Locale) async throws -> AirshipHTTPResponse<ContactAssociateChannelResult>)?

    init() {}

    public func resolve(
        channelID: String,
        contactID: String?,
        possiblyOrphanedContactID: String?
    ) async throws -> AirshipHTTPResponse<ContactIdentifyResult> {
        return try await resolveCallback!(channelID, contactID, possiblyOrphanedContactID)
    }

    public func identify(
        channelID: String,
        namedUserID: String,
        contactID: String?,
        possiblyOrphanedContactID: String?
    ) async throws -> AirshipHTTPResponse<ContactIdentifyResult> {
        return try await identifyCallback!(channelID, namedUserID, contactID, possiblyOrphanedContactID)
    }

    public func reset(
        channelID: String,
        possiblyOrphanedContactID: String?
    ) async throws -> AirshipHTTPResponse<ContactIdentifyResult> {
        return try await resetCallback!(channelID, possiblyOrphanedContactID)
    }

    public func update(
        contactID: String,
        tagGroupUpdates: [TagGroupUpdate]?,
        attributeUpdates: [AttributeUpdate]?,
        subscriptionListUpdates: [ScopedSubscriptionListUpdate]?
    ) async throws -> AirshipHTTPResponse<Void> {
        return try await updateCallback!(contactID, tagGroupUpdates, attributeUpdates, subscriptionListUpdates)
    }

    func associateChannel(contactID: String,
                          channelID: String,
                          channelType: ChannelType
    ) async throws -> AirshipHTTPResponse<ContactAssociateChannelResult> {
        return try await associateChannelCallback!(contactID, channelID, channelType)
    }

    public func registerEmail(
        contactID: String,
        address: String,
        options: EmailRegistrationOptions,
        locale: Locale
    ) async throws -> AirshipHTTPResponse<ContactAssociateChannelResult> {
        return try await registerEmailCallback!(contactID, address, options, locale)
    }

    public func registerSMS(
        contactID: String,
        msisdn: String,
        options: SMSRegistrationOptions,
        locale: Locale
    ) async throws -> AirshipHTTPResponse<ContactAssociateChannelResult> {
        return try await registerSMSCallback!(contactID, msisdn, options, locale)
    }
    
    public func registerOpen(
        contactID: String,
        address: String,
        options: OpenRegistrationOptions,
        locale: Locale
    ) async throws -> AirshipHTTPResponse<ContactAssociateChannelResult> {
        return try await registerOpenCallback!(contactID, address, options, locale)
    }

    func resend(resendOptions: ResendOptions) async throws -> AirshipHTTPResponse<Bool> {
        return try await resendCallback!(resendOptions)
    }

    func disassociateChannel(
        contactID: String,
        disassociateOptions: DisassociateOptions
    ) async throws -> AirshipHTTPResponse<ContactDisassociateChannelResult> {
        switch disassociateOptions {
        case .channel(let channel):
            return try await disassociateChannelCallback!(true, channel.channelID, channel.channelType)
        case .email(let email):
            return try await disassociateEmailCallback!(false, email.address, email.channelType)
        case .sms(let sms):
            return try await disassociateSMSCallback!(false, sms.msisdn, sms.senderID, sms.channelType)
        }
    }
}
