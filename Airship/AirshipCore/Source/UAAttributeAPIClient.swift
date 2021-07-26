/* Copyright Airship and Contributors */

/**
 * @note For internal use only. :nodoc:
 */
@objc
public class UAAttributeAPIClient : NSObject {

    @objc
    public let urlFactoryBlock: ((UARuntimeConfig, String) -> URL?)
    
    private let config: UARuntimeConfig
    private let session: UARequestSession

    @objc
    public init(config: UARuntimeConfig, session: UARequestSession, urlFactoryBlock: @escaping (UARuntimeConfig, String) -> URL?) {        self.config = config
        self.session = session
        self.urlFactoryBlock = urlFactoryBlock
        super.init()
    }

    @objc
    public class func channelClient(config: UARuntimeConfig) -> UAAttributeAPIClient {
        let urlBlock: ((UARuntimeConfig, String) -> URL?) = { config, identifier in
            let attributeEndpoint = "\(config.deviceAPIURL ?? "")/api/channels/\(identifier)/attributes?platform=ios"
            return URL(string: attributeEndpoint)
        }

        return UAAttributeAPIClient(
            config: config,
            session: UARequestSession(config: config),
            urlFactoryBlock: urlBlock)
    }

    @objc
    @discardableResult
    public func update(identifier: String,
                       mutations: UAAttributePendingMutations,
                       completionHandler: @escaping (UAHTTPResponse?, Error?) -> Void) -> UADisposable {

        AirshipLogger.debug("Updating attributes for identifier: \(identifier) with attribute payload: \(mutations).")

        let payloadData: Data? = try? UAJSONSerialization.data(withJSONObject: mutations.payload() ?? [:], options: [])

        let request = UARequest(builderBlock: { [self] builder in
            builder.url = urlFactoryBlock(config, identifier)
            builder.method = "POST"
            builder.username = config.appKey
            builder.password = config.appSecret
            builder.body = payloadData
            builder.setValue("application/vnd.urbanairship+json; version=3;", header: "Accept")
            builder.setValue("application/json", header: "Content-Type")
        })

        return session.performHTTPRequest(request, completionHandler: { data, response, error in
            guard let response = response else {
                AirshipLogger.debug("Update finished with error: \(error.debugDescription)")
                completionHandler(nil, error)
                return
            }

            AirshipLogger.debug("Update finished with response: \(response)")
            completionHandler(UAHTTPResponse(status: response.statusCode), nil)
        })
    }
}
