import Foundation

@testable import AirshipCore

public class TestContactAPIClient: ContactsAPIClientProtocol {

    var resolveCallback:
        ((String) async throws -> AirshipHTTPResponse<ContactAPIResponse>)?
   
    var identifyCallback:
        ((String, String, String?) async throws -> AirshipHTTPResponse<ContactAPIResponse>)?
  
    var resetCallback:
        ((String) async throws -> AirshipHTTPResponse<ContactAPIResponse>)?
    
    var updateCallback:
        ((String, [TagGroupUpdate]?, [AttributeUpdate]?, [ScopedSubscriptionListUpdate]?) async throws -> AirshipHTTPResponse<Void>)?
    
    var associateChannelCallback:
        ((String, String, ChannelType) async throws -> AirshipHTTPResponse<AssociatedChannel>)?
    
    var registerEmailCallback:
        ((String, String, EmailRegistrationOptions) async throws -> AirshipHTTPResponse<AssociatedChannel>)?
    
    var registerSMSCallback:
        ((String, String, SMSRegistrationOptions) async throws -> AirshipHTTPResponse<AssociatedChannel>)?
    
    var registerOpenCallback:
        ((String, String, OpenRegistrationOptions) async throws -> AirshipHTTPResponse<AssociatedChannel>)?
    
    var fetchSubscriptionListsCallback:
        ((String) async throws -> AirshipHTTPResponse<[String: [ChannelScope]]>)?
    
    init() {}

    public func resolve(
        channelID: String
    ) async throws -> AirshipHTTPResponse<ContactAPIResponse> {
        return try await resolveCallback!(channelID)
    }

    public func identify(
        channelID: String,
        namedUserID: String,
        contactID: String?
    ) async throws -> AirshipHTTPResponse<ContactAPIResponse> {
        return try await identifyCallback!(channelID, namedUserID, contactID)
    }

    public func reset(
        channelID: String
    ) async throws -> AirshipHTTPResponse<ContactAPIResponse> {
        return try await resetCallback!(channelID)
    }

    public func update(
        identifier: String,
        tagGroupUpdates: [TagGroupUpdate]?,
        attributeUpdates: [AttributeUpdate]?,
        subscriptionListUpdates: [ScopedSubscriptionListUpdate]?
    ) async throws -> AirshipHTTPResponse<Void> {
        return try await updateCallback!(identifier, tagGroupUpdates, attributeUpdates, subscriptionListUpdates)
    }

    public func associateChannel(
        identifier: String,
        channelID: String,
        channelType: ChannelType
    ) async throws -> AirshipHTTPResponse<AssociatedChannel> {
        return try await associateChannelCallback!(identifier, channelID, channelType)
    }

    public func registerEmail(
        identifier: String,
        address: String,
        options: EmailRegistrationOptions
    ) async throws -> AirshipHTTPResponse<AssociatedChannel> {
        return try await registerEmailCallback!(identifier, address, options)
    }

    public func registerSMS(
        identifier: String,
        msisdn: String,
        options: SMSRegistrationOptions
    ) async throws -> AirshipHTTPResponse<AssociatedChannel> {
        return try await registerSMSCallback!(identifier, msisdn, options)
    }

    public func registerOpen(
        identifier: String,
        address: String,
        options: OpenRegistrationOptions
    ) async throws -> AirshipHTTPResponse<AssociatedChannel> {
        return try await registerOpenCallback!(identifier, address, options)
    }
    
    public func fetchSubscriptionLists(
        _ identifier: String
    ) async throws -> AirshipHTTPResponse<[String: [ChannelScope]]> {
        return try await fetchSubscriptionListsCallback!(identifier)
    }

}
