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
    func registerEmail(emailOptIn: [EmailOptIn], address: String, completionHandler: @escaping (ChannelCreateResponse?, Error?) -> Void) -> Disposable
    
    @discardableResult
    func registerSms(msisdn: String, sender: String, optedIn: Bool, completionHandler: @escaping (ChannelCreateResponse?, Error?) -> Void) -> Disposable
    
    @discardableResult
    func updateEmail(channelID: String, emailOptIn: [EmailOptIn], address: String, completionHandler: @escaping (ChannelCreateResponse?, Error?) -> Void) -> Disposable
    
    @discardableResult
    func updateSms(channelID: String, msisdn: String, sender: String, optedIn: Bool, completionHandler: @escaping (ChannelCreateResponse?, Error?) -> Void) -> Disposable
    
    @discardableResult
    func optOutSms(msisdn: String, sender: String, completionHandler: @escaping (ChannelCreateResponse?, Error?) -> Void) -> Disposable
    
    
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
    private static let commercialOptInKey = "commercial_opted_in"
    private static let commercialOptOutKey = "commercial_opted_out"
    private static let transactionalOptInKey = "transactional_opted_in"
    private static let transactionalOptOutKey = "transactional_opted_out"
    private static let addressKey = "address"
    private static let msisdnKey = "msisdn"
    private static let senderKey = "sender"
    private static let optedInKey = "opted_in"
    private static let timezoneKey = "timezone"
    private static let localeCountryKey = "locale_country"
    private static let localeLanguageKey = "locale_language"
    

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
    func registerEmail(emailOptIn: [EmailOptIn], address: String, completionHandler: @escaping (ChannelCreateResponse?, Error?) -> Void) -> Disposable {
        
        AirshipLogger.debug("Creating an Email channel with address \(address)")

        let currentLocale = self.localeManager.currentLocale
        
        var channel: [String : String] = [
            ContactAPIClient.typeKey: "email",
            ContactAPIClient.addressKey: address,
            ContactAPIClient.timezoneKey: TimeZone.current.identifier,
            ContactAPIClient.localeCountryKey: currentLocale.regionCode ?? "",
            ContactAPIClient.localeLanguageKey: currentLocale.languageCode ?? ""
        ]
        
        for optIn in emailOptIn {
            channel[optIn.getEmailType()] = Utils.isoDateFormatterUTCWithDelimiter().string(from:Date())
        }
        
        let payload: [String : [String : String]] = [
            ContactAPIClient.channelKey: channel
        ]
        
        let request = self.request(payload, "\(config.deviceAPIURL ?? "")\(ContactAPIClient.channelsPath)/email")

        return session.performHTTPRequest(request, completionHandler: { (data, response, error) in
            
            guard let response = response else {
                AirshipLogger.debug("Creating Email channel finished with error: \(error.debugDescription)")
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
                    guard let channelID = jsonResponse?["channel_id"] as? String else {
                        completionHandler(nil, AirshipErrors.parseError("Missing channel_id"))
                        return
                    }

                    AirshipLogger.debug("Email channel created with response: \(response)")
                    let channelCreateResponse = ChannelCreateResponse(status: response.statusCode, channelID: channelID)
                    completionHandler(channelCreateResponse, nil)
                } catch {
                    completionHandler(nil, error)
                }
            } else {
                let channelCreateResponse = ChannelCreateResponse(status: response.statusCode, channelID: nil)
                completionHandler(channelCreateResponse, nil)
            }
        })
    }
    
    @discardableResult
    func registerSms(msisdn: String, sender: String, optedIn: Bool, completionHandler: @escaping (ChannelCreateResponse?, Error?) -> Void) -> Disposable {
        
        AirshipLogger.debug("Creating a SMS channel with msisdn \(msisdn) and sender \(sender)")

        let currentLocale = self.localeManager.currentLocale
        var payload: [String : String] = [
            ContactAPIClient.msisdnKey: msisdn,
            ContactAPIClient.senderKey: sender,
            ContactAPIClient.timezoneKey: TimeZone.current.identifier,
            ContactAPIClient.localeCountryKey: currentLocale.regionCode ?? "",
            ContactAPIClient.localeLanguageKey: currentLocale.languageCode ?? ""
        ]
        
        if optedIn {
            payload[ContactAPIClient.optedInKey] = Utils.isoDateFormatterUTCWithDelimiter().string(from:Date())
        }
        
        let request = self.request(payload, "\(config.deviceAPIURL ?? "")\(ContactAPIClient.channelsPath)/sms")

        return session.performHTTPRequest(request, completionHandler: { (data, response, error) in
            
            guard let response = response else {
                AirshipLogger.debug("Creating SMS channel finished with error: \(error.debugDescription)")
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
                    guard let channelID = jsonResponse?["channel_id"] as? String else {
                        completionHandler(nil, AirshipErrors.parseError("Missing channel_id"))
                        return
                    }

                    AirshipLogger.debug("SMS channel created with response: \(response)")
                    let channelCreateResponse = ChannelCreateResponse(status: response.statusCode, channelID: channelID)
                    completionHandler(channelCreateResponse, nil)
                } catch {
                    completionHandler(nil, error)
                }
            } else {
                let channelCreateResponse = ChannelCreateResponse(status: response.statusCode, channelID: nil)
                completionHandler(channelCreateResponse, nil)
            }
        })
    }
    
    @discardableResult
    func updateEmail(channelID: String, emailOptIn: [EmailOptIn], address: String, completionHandler: @escaping (ChannelCreateResponse?, Error?) -> Void) -> Disposable {
        
        AirshipLogger.debug("Associating Email to contact with channel ID \(channelID)")

        var channel: [String : String] = [
            ContactAPIClient.deviceTypeKey: "email",
            ContactAPIClient.addressKey: address
        ]
        
        for optIn in emailOptIn {
            channel[optIn.getEmailType()] = Utils.isoDateFormatterUTCWithDelimiter().string(from:Date())
        }
        
        let payload: [String : [String : String]] = [
            ContactAPIClient.channelKey: channel
        ]
        
        let request = self.request(payload, "\(config.deviceAPIURL ?? "")\(ContactAPIClient.channelsPath)/email/\(channelID)")

        return session.performHTTPRequest(request, completionHandler: { (data, response, error) in
            
            guard let response = response else {
                AirshipLogger.debug("Associating Email to contact finished with error: \(error.debugDescription)")
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
                    guard let channelID = jsonResponse?["channel_id"] as? String else {
                        completionHandler(nil, AirshipErrors.parseError("Missing channel_id"))
                        return
                    }

                    AirshipLogger.debug("Email associated to contact with response: \(response)")
                    let channelCreateResponse = ChannelCreateResponse(status: response.statusCode, channelID: channelID)
                    completionHandler(channelCreateResponse, nil)
                } catch {
                    completionHandler(nil, error)
                }
            } else {
                let channelCreateResponse = ChannelCreateResponse(status: response.statusCode, channelID: nil)
                completionHandler(channelCreateResponse, nil)
            }
        })
    }
    
    @discardableResult
    func updateSms(channelID: String, msisdn: String, sender: String, optedIn: Bool, completionHandler: @escaping (ChannelCreateResponse?, Error?) -> Void) -> Disposable {
        
        AirshipLogger.debug("Associating SMS to contact with channel ID \(channelID)")

        let currentLocale = self.localeManager.currentLocale
        var payload: [String : String] = [
            ContactAPIClient.msisdnKey: msisdn,
            ContactAPIClient.senderKey: sender,
            ContactAPIClient.timezoneKey: TimeZone.current.identifier,
            ContactAPIClient.localeCountryKey: currentLocale.regionCode ?? "",
            ContactAPIClient.localeLanguageKey: currentLocale.languageCode ?? ""
        ]
        
        if optedIn {
            payload[ContactAPIClient.optedInKey] = Utils.isoDateFormatterUTCWithDelimiter().string(from:Date())
        }
        
        let request = self.request(payload, "\(config.deviceAPIURL ?? "")\(ContactAPIClient.channelsPath)/sms/\(channelID)")

        return session.performHTTPRequest(request, completionHandler: { (data, response, error) in
            
            guard let response = response else {
                AirshipLogger.debug("Associating SMS to contact finished with error: \(error.debugDescription)")
                completionHandler(nil, error)
                return
            }

            if (response.statusCode == 200) {
                guard data != nil else {
                    completionHandler(nil, AirshipErrors.parseError("Missing body"))
                    return
                }

                AirshipLogger.debug("SMS associated with response: \(response)")
                let channelCreateResponse = ChannelCreateResponse(status: response.statusCode, channelID: nil)
                completionHandler(channelCreateResponse, nil)
            } else {
                let channelCreateResponse = ChannelCreateResponse(status: response.statusCode, channelID: nil)
                completionHandler(channelCreateResponse, nil)
            }
        })
    }
    
    @discardableResult
    func optOutSms(msisdn: String, sender: String, completionHandler: @escaping (ChannelCreateResponse?, Error?) -> Void) -> Disposable {
        
        AirshipLogger.debug("Optout SMS channel for msisdn \(msisdn) and sender \(sender)")

        let payload: [String : String] = [
            ContactAPIClient.msisdnKey: msisdn,
            ContactAPIClient.senderKey: sender
        ]
        
        let request = self.request(payload, "\(config.deviceAPIURL ?? "")\(ContactAPIClient.channelsPath)/sms/optout")

        return session.performHTTPRequest(request, completionHandler: { (data, response, error) in
            
            guard let response = response else {
                AirshipLogger.debug("Optout SMS channel finished with error: \(error.debugDescription)")
                completionHandler(nil, error)
                return
            }

            if (response.statusCode == 200) {
                guard data != nil else {
                    completionHandler(nil, AirshipErrors.parseError("Missing body"))
                    return
                }

                AirshipLogger.debug("Optout SMS channnel with response: \(response)")
                let channelCreateResponse = ChannelCreateResponse(status: response.statusCode, channelID: nil)
                completionHandler(channelCreateResponse, nil)
            } else {
                let channelCreateResponse = ChannelCreateResponse(status: response.statusCode, channelID: nil)
                completionHandler(channelCreateResponse, nil)
            }
        })
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
                "scope": list.scope.scopeString,
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


class ContactSubscriptionListFetchResponse : HTTPResponse {
    let result: ScopedSubscriptionLists?

    init(_ status: Int, _ result: ScopedSubscriptionLists? = nil) {
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
    
    func toScopedSubscriptionLists() throws -> ScopedSubscriptionLists {
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
        return ScopedSubscriptionLists(parsed)
    }
}





