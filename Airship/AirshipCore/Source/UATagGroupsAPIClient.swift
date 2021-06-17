/* Copyright Airship and Contributors */

/**
 * @note For internal use only. :nodoc:
 */
@objc
public class UATagGroupsAPIClient : NSObject {

    private var typeKey: String
    private var path: String
    private var config: UARuntimeConfig
    private var session: UARequestSession

    @objc
    public init(config: UARuntimeConfig, session: UARequestSession, typeKey: String, path: String) {
        self.config = config
        self.session = session
        self.typeKey = typeKey
        self.path = path

        super.init()
    }

    @objc
    public class func channelClient(withConfig config: UARuntimeConfig) -> UATagGroupsAPIClient {
        return UATagGroupsAPIClient(config: config,
                                    session: UARequestSession(config: config),
                                    typeKey: "ios_channel",
                                    path: "/api/channels/tags/")
    }

    @objc
    public class func namedUserClient(withConfig config: UARuntimeConfig) -> UATagGroupsAPIClient {
        return UATagGroupsAPIClient(config: config,
                                    session: UARequestSession(config: config),
                                    typeKey: "named_user_id",
                                    path: "/api/named_users/tags/")
    }

    @objc
    @discardableResult
    public func updateTagGroups(_ identifier: String, mutation: UATagGroupsMutation, completionHandler: @escaping (UAHTTPResponse?, Error?) -> Void) -> UADisposable {

        var payload = mutation.payload()
        payload["audience"] = [self.typeKey : identifier]

        AirshipLogger.debug("Updating tag groups with payload: \(payload)")

        let request = UARequest(builderBlock: { [self] builder in
            builder.url = URL(string: "\(config.deviceAPIURL ?? "")\(path)")
            builder.method = "POST"
            builder.username = config.appKey
            builder.password = config.appSecret
            builder.body = try? UAJSONSerialization.data(withJSONObject: payload, options: .prettyPrinted)
            builder.setValue("application/vnd.urbanairship+json; version=3;", header: "Accept")
            builder.setValue("application/json", header: "Content-Type")
        })

        return session.performHTTPRequest(request, completionHandler: { (data, response, error) in

            guard let response = response else {
                AirshipLogger.debug("Update finished with error: \(error.debugDescription)")
                completionHandler(nil, error)
                return
            }

            AirshipLogger.debug("Update finished with response: \(response)")

            if let data = data {
                if let responseBody = try? JSONSerialization.jsonObject(with: data, options: .allowFragments) as? [AnyHashable : Any] {
                    AirshipLogger.debug("Tag group response body: \(responseBody)")
                }
            }

            completionHandler(UAHTTPResponse.init(status: response.statusCode), nil)
        })
    }
}
