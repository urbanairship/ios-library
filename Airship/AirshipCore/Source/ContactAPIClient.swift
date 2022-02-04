/* Copyright Airship and Contributors */

import Foundation

// NOTE: For internal use only. :nodoc:
protocol ContactsAPIClientProtocol {
    @discardableResult
    func resolve(channelID: String, completionHandler: @escaping (ContactAPIResponse?, Error?) -> Void) -> Disposable

    @discardableResult
    func identify(channelID: String, namedUserID: String, contactID: String?, completionHandler: @escaping (ContactAPIResponse?, Error?) -> Void) -> Disposable
    
    @discardableResult
    func reset(channelID: String, completionHandler: @escaping (ContactAPIResponse?, Error?) -> Void) -> Disposable
    
    @discardableResult
    func update(identifier: String,
                tagGroupUpdates: [TagGroupUpdate]?,
                attributeUpdates: [AttributeUpdate]?,
                subscriptionListUpdates: [ScopedSubscriptionListUpdate]?,
                completionHandler: @escaping (HTTPResponse?, Error?) -> Void) -> Disposable
    
    @discardableResult
    func associateChannel(identifier: String,
                          channelID: String,
                          channelType: ChannelType,
                          completionHandler: @escaping (ContactAssociatedChannelResponse?, Error?) -> Void) -> Disposable
    
    @discardableResult
    func registerEmail(identifier:String, address: String, options: EmailRegistrationOptions, completionHandler: @escaping (ContactAssociatedChannelResponse?, Error?) -> Void) -> Disposable
    
    @discardableResult
    func registerSMS(identifier:String, msisdn: String, options: SMSRegistrationOptions, completionHandler: @escaping (ContactAssociatedChannelResponse?, Error?) -> Void) -> Disposable
    
    @discardableResult
    func registerOpen(identifier:String, address: String, options: OpenRegistrationOptions, completionHandler: @escaping (ContactAssociatedChannelResponse?, Error?) -> Void) -> Disposable

    @discardableResult
    func fetchSubscriptionLists(_ identifier: String, completionHandler: @escaping (ContactSubscriptionListFetchResponse?, Error?) -> Void) -> Disposable;
}

// NOTE: For internal use only. :nodoc:
class ContactAPIClient : ContactsAPIClientProtocol {
    private static let path = "/api/contacts"
    private static let channelsPath = "/api/channels"
    
    private static let subscriptionListPath = "/api/subscription_lists/contacts/"

    private static let channelIDKey = "channel_id"
    private static let namedUserIDKey = "named_user_id"
    private static let contactIDKey = "contact_id"
    private static let deviceTypeKey = "device_type"
    private static let channelKey = "channel"
    private static let typeKey = "type"
    private static let commercialOptedInKey = "commercial_opted_in"
    private static let commercialOptedOutKey = "commercial_opted_out"
    private static let transactionalOptedInKey = "transactional_opted_in"
    private static let transactionalOptedOutKey = "transactional_opted_out"
    private static let optInModeKey = "opt_in_mode"
    private static let propertiesKey = "properties"
    private static let addressKey = "address"
    private static let msisdnKey = "msisdn"
    private static let senderKey = "sender"
    private static let optedInKey = "opted_in"
    private static let timezoneKey = "timezone"
    private static let localeCountryKey = "locale_country"
    private static let localeLanguageKey = "locale_language"
    private static let identifiersKey = "identifiers"
    private static let openKey = "open"
    private static let openPlatformName = "open_platform_name"
    private static let optInKey = "opt_in"
    private static let associateKey = "associate"
    
    private let config: RuntimeConfig
    private let session: RequestSession
    private let localeManager: LocaleManager
    
    private lazy var decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    init(config: RuntimeConfig, session: RequestSession) {
        self.config = config
        self.session = session
        self.localeManager = LocaleManager(dataStore: PreferenceDataStore(appKey: config.appKey))
    }

    convenience init(config: RuntimeConfig) {
        self.init(config: config, session: RequestSession(config: config))
    }
    
    @discardableResult
    func resolve(channelID: String, completionHandler: @escaping (ContactAPIResponse?, Error?) -> Void) -> Disposable {

        AirshipLogger.debug("Resolving contact with channel ID \(channelID)")

        let payload: [String : String] = [
            ContactAPIClient.channelIDKey: channelID,
            ContactAPIClient.deviceTypeKey: "ios"
        ]

        let request = self.request(payload, "\(config.deviceAPIURL ?? "")\(ContactAPIClient.path)/resolve")

        return session.performHTTPRequest(request, completionHandler: { (data, response, error) in
            guard let response = response else {
                AirshipLogger.debug("Resolving contact finished with error: \(error.debugDescription)")
                completionHandler(nil, error)
                return
            }

            if (response.statusCode == 200) {
                do {
                    guard data != nil else {
                        completionHandler(nil, AirshipErrors.parseError("Missing body"))
                        return
                    }

                    let jsonResponse = try JSONSerialization.jsonObject(with: data!, options: .allowFragments) as? [AnyHashable : Any]
                    guard let contactID = jsonResponse?["contact_id"] as? String else {
                        completionHandler(nil, AirshipErrors.parseError("Missing contact_id"))
                        return
                    }
                    guard let isAnonymous = jsonResponse?["is_anonymous"] as? Bool else {
                        completionHandler(nil, AirshipErrors.parseError("Missing is_anonymous"))
                        return
                    }

                    AirshipLogger.debug("Resolved contact with response: \(response)")
                    let contactDataResponse = ContactAPIResponse(status: response.statusCode, contactID: contactID, isAnonymous: isAnonymous)
                    completionHandler(contactDataResponse, nil)
                } catch {
                    completionHandler(nil, error)
                }
            } else {
                let contactDataResponse = ContactAPIResponse(status: response.statusCode, contactID: nil, isAnonymous: false)
                completionHandler(contactDataResponse, nil)
            }
        })
    }

    @discardableResult
    func identify(channelID: String, namedUserID: String, contactID: String?, completionHandler: @escaping (ContactAPIResponse?, Error?) -> Void) -> Disposable {

        AirshipLogger.debug("Identifying contact with channel ID \(channelID)")

        var payload: [String : String] = [
            ContactAPIClient.channelIDKey: channelID,
            ContactAPIClient.namedUserIDKey: namedUserID,
            ContactAPIClient.deviceTypeKey: "ios"
        ]

        if (contactID != nil) {
            payload[ContactAPIClient.contactIDKey] = contactID
        }
        
        let request = self.request(payload, "\(config.deviceAPIURL ?? "")\(ContactAPIClient.path)/identify")

        return session.performHTTPRequest(request, completionHandler: { (data, response, error) in
            
            guard let response = response else {
                AirshipLogger.debug("Identifying contact finished with error: \(error.debugDescription)")
                completionHandler(nil, error)
                return
            }

            if (response.statusCode == 200) {
                do {
                    guard data != nil else {
                        completionHandler(nil, AirshipErrors.parseError("Missing body"))
                        return
                    }

                    let jsonResponse = try JSONSerialization.jsonObject(with: data!, options: .allowFragments) as? [AnyHashable : Any]
                    guard let contactID = jsonResponse?["contact_id"] as? String else {
                        completionHandler(nil, AirshipErrors.parseError("Missing contact_id"))
                        return
                    }

                    AirshipLogger.debug("Identified contact with response: \(response)")
                    let contactDataResponse = ContactAPIResponse(status: response.statusCode, contactID: contactID, isAnonymous: false)
                    completionHandler(contactDataResponse, nil)
                } catch {
                    completionHandler(nil, error)
                }
            } else {
                let contactDataResponse = ContactAPIResponse(status: response.statusCode, contactID: nil, isAnonymous: false)
                completionHandler(contactDataResponse, nil)
            }
        })
    }
    
    @discardableResult
    func reset(channelID: String, completionHandler: @escaping (ContactAPIResponse?, Error?) -> Void) -> Disposable {

        AirshipLogger.debug("Resetting contact with channel ID \(channelID)")

        let payload: [String : String] = [
            ContactAPIClient.channelIDKey: channelID,
            ContactAPIClient.deviceTypeKey: "ios"
        ]

        let request = self.request(payload, "\(config.deviceAPIURL ?? "")\(ContactAPIClient.path)/reset")

        return session.performHTTPRequest(request, completionHandler: { (data, response, error) in
            guard let response = response else {
                AirshipLogger.debug("Resetting contact finished with error: \(error.debugDescription)")
                completionHandler(nil, error)
                return
            }

            if (response.statusCode == 200) {
                do {
                    guard data != nil else {
                        completionHandler(nil, AirshipErrors.parseError("Missing body"))
                        return
                    }

                    let jsonResponse = try JSONSerialization.jsonObject(with: data!, options: .allowFragments) as? [AnyHashable : Any]
                    guard let contactID = jsonResponse?["contact_id"] as? String else {
                        completionHandler(nil, AirshipErrors.parseError("Missing contact_id"))
                        return
                    }

                    AirshipLogger.debug("Reset contact with response: \(response)")
                    let contactDataResponse = ContactAPIResponse(status: response.statusCode, contactID: contactID, isAnonymous: false)
                    completionHandler(contactDataResponse, nil)
                } catch {
                    completionHandler(nil, error)
                }
            } else {
                let contactDataResponse = ContactAPIResponse(status: response.statusCode, contactID: nil, isAnonymous: false)
                completionHandler(contactDataResponse, nil)
            }
        })
    }
    
    @discardableResult
    func update(identifier: String,
                tagGroupUpdates: [TagGroupUpdate]?,
                attributeUpdates: [AttributeUpdate]?,
                subscriptionListUpdates: [ScopedSubscriptionListUpdate]?,
                completionHandler: @escaping (HTTPResponse?, Error?) -> Void) -> Disposable {

        AirshipLogger.debug("Updating contact with identifier \(identifier)")


        var payload: [String: Any] = [:]
        
        if let attributeUpdates = attributeUpdates, !attributeUpdates.isEmpty {
            payload["attributes"] = map(attributeUpdates: attributeUpdates)
        }
        
        if let tagGroupUpdates = tagGroupUpdates, !tagGroupUpdates.isEmpty {
            payload["tags"] = map(tagUpdates: tagGroupUpdates)
        }
        
        if let subscriptionListUpdates = subscriptionListUpdates, !subscriptionListUpdates.isEmpty {
            payload["subscription_lists"] = map(subscriptionListUpdates: subscriptionListUpdates)
        }
        
        let request = self.request(payload, "\(config.deviceAPIURL ?? "")/api/contacts/\(identifier)")

        return session.performHTTPRequest(request, completionHandler: { (data, response, error) in
            guard let response = response else {
                AirshipLogger.debug("Update finished with error: \(error.debugDescription)")
                completionHandler(nil, error)
                return
            }

            AirshipLogger.debug("Update finished with response: \(response)")
            completionHandler(HTTPResponse(status: response.statusCode), nil)
        })
    }
    
    @discardableResult
    func associateChannel(identifier: String,
                          channelID: String,
                          channelType: ChannelType,
                          completionHandler: @escaping (ContactAssociatedChannelResponse?, Error?) -> Void) -> Disposable {

        AirshipLogger.debug("Associate channel \(channelID) with contact \(identifier)")
            
        let payload: [String: Any] = [
            ContactAPIClient.associateKey: [
                [
                    ContactAPIClient.deviceTypeKey: channelType.stringValue,
                    ContactAPIClient.channelIDKey: channelID
                ]
            ]
        ]
        
        let request = self.request(payload, "\(config.deviceAPIURL ?? "")/api/contacts/\(identifier)")

        return session.performHTTPRequest(request) { data, response, error in
            guard let response = response else {
                AirshipLogger.debug("Associate channel finished with error: \(error.debugDescription)")
                completionHandler(nil, error)
                return
            }
            AirshipLogger.debug("Associate channel finished with response: \(response)")
            if (response.statusCode == 200) {
                let channel = AssociatedChannel(channelType: channelType, channelID: channelID)
                let regResponse = ContactAssociatedChannelResponse(status: response.statusCode, channel: channel)
                completionHandler(regResponse, nil)
            } else {
                let regResponse = ContactAssociatedChannelResponse(status: response.statusCode)
                completionHandler(regResponse, nil)
            }
        }
    }
    
    @discardableResult
    func registerEmail(identifier: String,
                       address: String,
                       options: EmailRegistrationOptions,
                       completionHandler: @escaping (ContactAssociatedChannelResponse?, Error?) -> Void) -> Disposable {
        
        let currentLocale = self.localeManager.currentLocale
        
        var channelPayload: [String : Any] = [
            ContactAPIClient.typeKey: "email",
            ContactAPIClient.addressKey: address,
            ContactAPIClient.timezoneKey: TimeZone.current.identifier,
            ContactAPIClient.localeCountryKey: currentLocale.regionCode ?? "",
            ContactAPIClient.localeLanguageKey: currentLocale.languageCode ?? ""
        ]
        
        let formatter = Utils.isoDateFormatterUTCWithDelimiter()
        if let transactionalOptedIn = options.transactionalOptedIn {
            channelPayload[ContactAPIClient.transactionalOptedInKey] = formatter.string(from:transactionalOptedIn)
        }
        
        if let commercialOptedIn = options.commercialOptedIn {
            channelPayload[ContactAPIClient.commercialOptedInKey] = formatter.string(from:commercialOptedIn)
        }
                
        var payload: [String : Any] = [
            ContactAPIClient.channelKey: channelPayload,
            ContactAPIClient.optInModeKey: options.doubleOptIn ? "double" : "classic"
        ]
        
        if let properties = options.properties {
            payload[ContactAPIClient.propertiesKey] = properties.value()
        }
        
        let request = self.request(payload, "\(config.deviceAPIURL ?? "")\(ContactAPIClient.channelsPath)/restricted/email")
        
        AirshipLogger.debug("Creating an Email channel with address \(address)")
        return registerChannel(identifier,
                               request: request,
                               channelType: .email,
                               completionHandler: completionHandler)

    }
    
    @discardableResult
    func registerSMS(identifier: String,
                     msisdn: String,
                     options: SMSRegistrationOptions,
                     completionHandler: @escaping (ContactAssociatedChannelResponse?, Error?) -> Void) -> Disposable {
        
        let currentLocale = self.localeManager.currentLocale
        let payload: [String : Any] = [
            ContactAPIClient.msisdnKey: msisdn,
            ContactAPIClient.senderKey: options.senderID,
            ContactAPIClient.timezoneKey: TimeZone.current.identifier,
            ContactAPIClient.localeCountryKey: currentLocale.regionCode ?? "",
            ContactAPIClient.localeLanguageKey: currentLocale.languageCode ?? ""
        ]
        
        let request = self.request(payload, "\(config.deviceAPIURL ?? "")\(ContactAPIClient.channelsPath)/restricted/sms")

        AirshipLogger.debug("Registering an SMS channel with msisdn \(msisdn) and sender \(options.senderID)")
        return registerChannel(identifier,
                               request: request,
                               channelType: .sms,
                               completionHandler: completionHandler)
    }
    
    @discardableResult
    func registerOpen(identifier: String, address: String, options: OpenRegistrationOptions, completionHandler: @escaping (ContactAssociatedChannelResponse?, Error?) -> Void) -> Disposable {
        let currentLocale = self.localeManager.currentLocale
        
        var openPayload: [String : Any] = [
            ContactAPIClient.openPlatformName: options.platformName
        ]
        
        if let identifiers = options.identifiers {
            var identifiersPayload: [String : Any] = [:]
            for (key, value) in identifiers {
                identifiersPayload[key] = value
            }
            openPayload[ContactAPIClient.identifiersKey] = identifiersPayload
        }
        
        let payload: [String : Any] = [
            ContactAPIClient.channelKey: [
                ContactAPIClient.typeKey: "open",
                ContactAPIClient.addressKey: address,
                ContactAPIClient.timezoneKey: TimeZone.current.identifier,
                ContactAPIClient.localeCountryKey: currentLocale.regionCode ?? "",
                ContactAPIClient.localeLanguageKey: currentLocale.languageCode ?? "",
                ContactAPIClient.optInKey: true,
                ContactAPIClient.openKey: openPayload
            ]
        ]
        
        let request = self.request(payload, "\(config.deviceAPIURL ?? "")\(ContactAPIClient.channelsPath)/restricted/open")

        AirshipLogger.debug("Registering an open channel with address \(address)")
        return registerChannel(identifier,
                               request: request,
                               channelType: .open,
                               completionHandler: completionHandler)
    }
    
    private func registerChannel(_ identifier: String,
                                 request: Request,
                                 channelType: ChannelType,
                                 completionHandler: @escaping (ContactAssociatedChannelResponse?, Error?) -> Void) -> Disposable {
        
        let lock = Lock()
        var requestDisposable: Disposable? = nil
        var isDisposed = false
        
        let disposable = Disposable {
            lock.sync {
                requestDisposable?.dispose()
                isDisposed = true
            }
        }
        
        requestDisposable = session.performHTTPRequest(request, completionHandler: { (data, response, error) in
            guard let response = response else {
                AirshipLogger.debug("Creating \(channelType) channel finished with error: \(error.debugDescription)")
                completionHandler(nil, error)
                return
            }

            AirshipLogger.debug("Contact channel \(channelType) created with response: \(response)")
            guard response.statusCode == 200 || response.statusCode == 201 else {
                let regResponse = ContactAssociatedChannelResponse(status: response.statusCode)
                completionHandler(regResponse, nil)
                return
            }
            
            do {
                guard let channelID = try self.parseChannelID(data: data) else {
                    completionHandler(nil, AirshipErrors.error("Missing channel ID"))
                    return
                }
                
                lock.sync {
                    if (isDisposed) {
                        completionHandler(nil, AirshipErrors.error("cancelled"))
                    } else {
                        requestDisposable = self.associateChannel(identifier: identifier,
                                                                  channelID: channelID,
                                                                  channelType: channelType,
                                                                  completionHandler: completionHandler)
                    }
                }
            } catch {
                completionHandler(nil, error)
            }
        })
        
        return disposable
    }
    
    private func parseChannelID(data: Data?) throws -> String? {
        guard let data = data else {
            return nil
        }
        
        let jsonResponse = try JSONSerialization.jsonObject(with: data, options: .allowFragments) as? [AnyHashable : Any]

        return jsonResponse?["channel_id"] as? String
    }
    
    private func request(_ payload: [AnyHashable : Any], _ urlString: String) -> Request {
        return Request(builderBlock: { [self] builder in
            builder.method = "POST"
            builder.url = URL(string: urlString)
            builder.username = config.appKey
            builder.password = config.appSecret
            builder.setValue("application/vnd.urbanairship+json; version=3;", header: "Accept")
            builder.setValue("application/json", header: "Content-Type")
            builder.body = try? JSONUtils.data(payload, options: [])
        })
    }
    
    private func map(subscriptionListUpdates: [ScopedSubscriptionListUpdate]) -> [[AnyHashable : Any]] {
        return AudienceUtils.collapse(subscriptionListUpdates).map { (list) -> ([AnyHashable : Any]) in
            var action : String
            switch(list.type) {
            case .subscribe:
                action = "subscribe"
            case .unsubscribe:
                action = "unsubscribe"
            }
            return [
                "action": action,
                "list_id": list.listId,
                "scope": list.scope.stringValue,
                "timestamp": Utils.isoDateFormatterUTCWithDelimiter().string(from: list.date)
            ]
        }
    }
    
    private func map(attributeUpdates: [AttributeUpdate]) -> [[AnyHashable : Any]] {
        return AudienceUtils.collapse(attributeUpdates).compactMap { (attribute) -> ([AnyHashable : Any]?) in
            switch(attribute.type) {
            case .set:
                guard let value = attribute.jsonValue?.value() else {
                    return nil
                }
                
                return [
                    "action": "set",
                    "key": attribute.attribute,
                    "value": value,
                    "timestamp": Utils.isoDateFormatterUTCWithDelimiter().string(from: attribute.date)
                ]
            case .remove:
                return [
                    "action": "remove",
                    "key": attribute.attribute,
                    "timestamp": Utils.isoDateFormatterUTCWithDelimiter().string(from: attribute.date)
                ]
            }
        }
    }
    
    private func map(tagUpdates: [TagGroupUpdate]) -> [AnyHashable : Any] {
        var tagsPayload : [String : [String: [String]]] = [:]
        
        AudienceUtils.collapse(tagUpdates).forEach { tagUpdate in
            switch (tagUpdate.type) {
            case .add:
                if (tagsPayload["add"] == nil) {
                    tagsPayload["add"] = [:]
                }
                tagsPayload["add"]?[tagUpdate.group] = tagUpdate.tags
                break
            case .remove:
                if (tagsPayload["remove"] == nil) {
                    tagsPayload["remove"] = [:]
                }
                tagsPayload["remove"]?[tagUpdate.group] = tagUpdate.tags
                break
            case .set:
                if (tagsPayload["set"] == nil) {
                    tagsPayload["set"] = [:]
                }
                tagsPayload["set"]?[tagUpdate.group] = tagUpdate.tags
                break
            }
        }
        
        return tagsPayload
    }
    

    @discardableResult
    func fetchSubscriptionLists(_ identifier: String,
                                completionHandler: @escaping (ContactSubscriptionListFetchResponse?, Error?) -> Void) -> Disposable {

        AirshipLogger.debug("Retrieving subscription lists associated with a contact")

        let request = Request(builderBlock: { [self] builder in
            builder.method = "GET"
            builder.url = URL(string: "\(config.deviceAPIURL ?? "")\(ContactAPIClient.subscriptionListPath)\(identifier)")
            builder.username = config.appKey
            builder.password = config.appSecret
            builder.setValue("application/vnd.urbanairship+json; version=3;", header: "Accept")
        })

        return session.performHTTPRequest(request, completionHandler: { (data, response, error) in
            guard let response = response else {
                AirshipLogger.debug("Retrieving subscription lists associated with a contact finished with error: \(error.debugDescription)")
                completionHandler(nil, error)
                return
            }

            if (response.statusCode == 200) {
                AirshipLogger.debug("Retrieved lists with response: \(response)")

                do {
                    guard let data = data else {
                        completionHandler(nil, AirshipErrors.parseError("Missing body"))
                        return
                    }
                    
                    let parsedBody = try self.decoder.decode(SubscriptionResponseBody.self,
                                                             from: data)
                    let scopedLists = try parsedBody.toScopedSubscriptionLists()
                    let clientResponse = ContactSubscriptionListFetchResponse(response.statusCode, scopedLists)
                    completionHandler(clientResponse, nil)
                } catch {
                    completionHandler(nil, error)
                }
            } else {
                let clientResponse = ContactSubscriptionListFetchResponse(response.statusCode)
                completionHandler(clientResponse, nil)
            }
        })
    }
}


class ContactAssociatedChannelResponse : HTTPResponse {

    public let channel: AssociatedChannel?

    public init(status: Int, channel: AssociatedChannel? = nil) {
        self.channel = channel
        super.init(status: status)
    }
}


class ContactSubscriptionListFetchResponse : HTTPResponse {
    let result: [String: [ChannelScope]]?

    init(_ status: Int, _ result: [String: [ChannelScope]]? = nil) {
        self.result = result
        super.init(status: status)
    }
}

internal struct SubscriptionResponseBody : Decodable {
    let subscriptionLists: [Entry]
    
    enum CodingKeys: String, CodingKey {
        case subscriptionLists = "subscription_lists"
    }
    
    struct Entry : Decodable, Equatable {
        let lists: [String]
        let scope: String
        
        enum CodingKeys: String, CodingKey {
            case lists = "list_ids"
            case scope = "scope"
        }
    }
    
    func toScopedSubscriptionLists() throws -> [String: [ChannelScope]] {
        var parsed: [String: [ChannelScope]] = [:]
        try self.subscriptionLists.forEach { entry in
            let scope = try ChannelScope.fromString(entry.scope)
            entry.lists.forEach { listID in
                var scopes = parsed[listID] ?? []
                if (!scopes.contains(scope)) {
                    scopes.append(scope)
                    parsed[listID] = scopes
                }
            }
        }
        return parsed
    }
}





