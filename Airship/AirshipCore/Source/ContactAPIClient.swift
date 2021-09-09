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
                completionHandler: @escaping (HTTPResponse?, Error?) -> Void) -> Disposable
}

// NOTE: For internal use only. :nodoc:
class ContactAPIClient : ContactsAPIClientProtocol {
    private static let path = "/api/contacts"

    private static let channelIDKey = "channel_id"
    private static let namedUserIDKey = "named_user_id"
    private static let contactIDKey = "contact_id"
    private static let deviceTypeKey = "device_type"

    private let config: RuntimeConfig
    private let session: RequestSession

    init(config: RuntimeConfig, session: RequestSession) {
        self.config = config
        self.session = session
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
                completionHandler: @escaping (HTTPResponse?, Error?) -> Void) -> Disposable {

        AirshipLogger.debug("Updating contact with identifier \(identifier)")

        if (tagGroupUpdates?.isEmpty ?? true && attributeUpdates?.isEmpty ?? true) {
            completionHandler(nil, AirshipErrors.error("Both tags & attributes are empty"))
        }
        
        var payload: [String: Any] = [:]
        
        if let attributes = attributeUpdates {
            payload["attributes"] = map(attributeUpdates: AudienceUtils.collapse(attributes))
        }
        
        if let tags = tagGroupUpdates {
            payload["tags"] = map(tagUpdates: AudienceUtils.collapse(tags))            
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
    
    
    private func map(attributeUpdates: [AttributeUpdate]) -> [[AnyHashable : Any]] {
        return attributeUpdates.map { (attribute) -> ([AnyHashable : Any]) in
            switch(attribute.type) {
            case .set:
                return [
                    "action": "set",
                    "key": attribute.attribute,
                    "value": attribute.jsonValue!.value()!,
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
}

