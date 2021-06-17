/* Copyright Airship and Contributors */

/**
 * @note For internal use only. :nodoc:
 */
@objc
public class UANamedUserAPIClient : NSObject {
    private static let path = "/api/named_users"

    private static let channelIDKey = "channel_id"
    private static let deviceTypeKey = "device_type"
    private static let namedUserIDKey = "named_user_id"

    private let config: UARuntimeConfig
    private let session: UARequestSession

    @objc
    public init(config: UARuntimeConfig, session: UARequestSession) {
        self.config = config
        self.session = session
        super.init()
    }

    @objc
    public convenience init(config: UARuntimeConfig) {
        self.init(config: config, session: UARequestSession(config: config))
    }

    @objc
    @discardableResult
    public func associate(_ identifier: String, channelID: String, completionHandler: @escaping (UAHTTPResponse?, Error?) -> Void) -> UADisposable {

        AirshipLogger.debug("Associating channel \(channelID) with named user ID: \(identifier)")

        let payload: [String : String] = [
            UANamedUserAPIClient.channelIDKey: channelID,
            UANamedUserAPIClient.deviceTypeKey: "ios",
            UANamedUserAPIClient.namedUserIDKey: identifier
        ]

        let request = self.request(payload, "\(config.deviceAPIURL ?? "")\(UANamedUserAPIClient.path)/associate")

        return session.performHTTPRequest(request, completionHandler: { (data, response, error) in
            guard let response = response else {
                AirshipLogger.debug("Associated named user finished with error: \(error.debugDescription)")
                completionHandler(nil, error)
                return
            }

            AirshipLogger.debug("Associated named user with response: \(response)")
            completionHandler(UAHTTPResponse(status: response.statusCode), nil)
        })
    }

    @objc
    @discardableResult
    public func disassociate(_ channelID: String, completionHandler: @escaping (UAHTTPResponse?, Error?) -> Void) -> UADisposable {
        AirshipLogger.debug("Disassociating channel \(channelID) from named user ID")

        let payload: [String : String] = [
            UANamedUserAPIClient.channelIDKey: channelID,
            UANamedUserAPIClient.deviceTypeKey: "ios",
        ]

        let request = self.request(payload, "\(config.deviceAPIURL ?? "")\(UANamedUserAPIClient.path)/disassociate")

        return session.performHTTPRequest(request, completionHandler: { (data, response, error) in
            guard let response = response else {
                AirshipLogger.debug("Disassociated named user finished with error: \(error.debugDescription)")
                completionHandler(nil, error)
                return
            }

            AirshipLogger.debug("Disassociated named user with response: \(response)")
            completionHandler(UAHTTPResponse(status: response.statusCode), nil)
        })
    }

    private func request(_ payload: [AnyHashable : Any], _ urlString: String) -> UARequest {
        return UARequest(builderBlock: { [self] builder in
            builder.method = "POST"
            builder.url = URL(string: urlString)
            builder.username = config.appKey
            builder.password = config.appSecret
            builder.setValue("application/vnd.urbanairship+json; version=3;", header: "Accept")
            builder.setValue("application/json", header: "Content-Type")
            builder.body = try? UAJSONSerialization.data(withJSONObject: payload, options: [])
        })
    }
}
