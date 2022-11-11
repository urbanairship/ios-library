import Foundation

@testable import AirshipCore

public class TestContactAPIClient: ContactsAPIClientProtocol {

    var resolveCallback:
        ((String, ((ContactAPIResponse?, Error?) -> Void)) -> Void)?
    var identifyCallback:
        (
            (String, String, String?, ((ContactAPIResponse?, Error?) -> Void))
                -> Void
        )?
    var resetCallback:
        ((String, ((ContactAPIResponse?, Error?) -> Void)) -> Void)?
    var updateCallback:
        (
            (
                String, [TagGroupUpdate]?, [AttributeUpdate]?,
                [ScopedSubscriptionListUpdate]?,
                ((HTTPResponse?, Error?) -> Void)
            ) -> Void
        )?
    var associateChannelCallback:
        (
            (
                String, String, ChannelType,
                ((ContactAssociatedChannelResponse?, Error?) -> Void)
            ) -> Void
        )?
    var registerEmailCallback:
        (
            (
                String, String, EmailRegistrationOptions,
                ((ContactAssociatedChannelResponse?, Error?) -> Void)
            ) -> Void
        )?
    var registerSMSCallback:
        (
            (
                String, String, SMSRegistrationOptions,
                ((ContactAssociatedChannelResponse?, Error?) -> Void)
            ) -> Void
        )?
    var registerOpenCallback:
        (
            (
                String, String, OpenRegistrationOptions,
                ((ContactAssociatedChannelResponse?, Error?) -> Void)
            ) -> Void
        )?
    var fetchSubscriptionListsCallback:
        (
            (String, ((ContactSubscriptionListFetchResponse?, Error?) -> Void))
                ->
                Void
        )?
    var defaultCallback: ((String) -> Void)?
    init() {}

    public func resolve(
        channelID: String,
        completionHandler: @escaping (ContactAPIResponse?, Error?) -> Void
    ) -> Disposable {
        if let callback = resolveCallback {
            callback(channelID, completionHandler)
        } else {
            defaultCallback?("resolve")
        }

        return Disposable()
    }

    public func identify(
        channelID: String,
        namedUserID: String,
        contactID: String?,
        completionHandler: @escaping (ContactAPIResponse?, Error?) -> Void
    ) -> Disposable {
        if let callback = identifyCallback {
            callback(channelID, namedUserID, contactID, completionHandler)
        } else {
            defaultCallback?("identify")
        }

        return Disposable()
    }

    public func reset(
        channelID: String,
        completionHandler: @escaping (ContactAPIResponse?, Error?) -> Void
    ) -> Disposable {
        if let callback = resetCallback {
            callback(channelID, completionHandler)
        } else {
            defaultCallback?("reset")
        }

        return Disposable()
    }

    public func update(
        identifier: String,
        tagGroupUpdates: [TagGroupUpdate]?,
        attributeUpdates: [AttributeUpdate]?,
        subscriptionListUpdates: [ScopedSubscriptionListUpdate]?,
        completionHandler: @escaping (HTTPResponse?, Error?) -> Void
    ) -> Disposable {
        if let callback = updateCallback {
            callback(
                identifier,
                tagGroupUpdates,
                attributeUpdates,
                subscriptionListUpdates,
                completionHandler
            )
        } else {
            defaultCallback?("update")
        }

        return Disposable()
    }

    public func associateChannel(
        identifier: String,
        channelID: String,
        channelType: ChannelType,
        completionHandler: @escaping (ContactAssociatedChannelResponse?, Error?)
            ->
            Void
    ) -> Disposable {
        if let callback = associateChannelCallback {
            callback(identifier, channelID, channelType, completionHandler)
        } else {
            defaultCallback?("associateChannel")
        }

        return Disposable()
    }

    public func registerEmail(
        identifier: String,
        address: String,
        options: EmailRegistrationOptions,
        completionHandler: @escaping (ContactAssociatedChannelResponse?, Error?)
            ->
            Void
    ) -> Disposable {
        if let callback = registerEmailCallback {
            callback(identifier, address, options, completionHandler)
        } else {
            defaultCallback?("registerEmail")
        }

        return Disposable()
    }

    public func registerSMS(
        identifier: String,
        msisdn: String,
        options: SMSRegistrationOptions,
        completionHandler: @escaping (ContactAssociatedChannelResponse?, Error?)
            ->
            Void
    ) -> Disposable {
        if let callback = registerSMSCallback {
            callback(identifier, msisdn, options, completionHandler)
        } else {
            defaultCallback?("registerSMS")
        }

        return Disposable()
    }

    public func registerOpen(
        identifier: String,
        address: String,
        options: OpenRegistrationOptions,
        completionHandler: @escaping (ContactAssociatedChannelResponse?, Error?)
            ->
            Void
    ) -> Disposable {
        if let callback = registerOpenCallback {
            callback(identifier, address, options, completionHandler)
        } else {
            defaultCallback?("registerOpen")
        }

        return Disposable()
    }

    public func fetchSubscriptionLists(
        _ identifier: String,
        completionHandler: @escaping (
            ContactSubscriptionListFetchResponse?, Error?
        )
            -> Void
    ) -> Disposable {
        if let callback = fetchSubscriptionListsCallback {
            callback(identifier, completionHandler)
        } else {
            defaultCallback?("fetchSubscriptionLists")
        }

        return Disposable()
    }

}
