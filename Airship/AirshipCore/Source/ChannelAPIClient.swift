/* Copyright Airship and Contributors */


/**
 * - Note: For internal use only. :nodoc:
 */ 
@objc(UAChannelAPIClient)
public class ChannelAPIClient : NSObject {
    private let path = "/api/channels/"

    private let config: RuntimeConfig
    private let session: RequestSession

    @objc
    public init(config: RuntimeConfig, session: RequestSession) {
        self.config = config
        self.session = session
        super.init()
    }

    @objc
    public convenience init(config: RuntimeConfig) {
        self.init(config: config, session: RequestSession(config: config))
    }

    @objc
    @discardableResult
    public func createChannel(withPayload payload: ChannelRegistrationPayload, completionHandler: @escaping (ChannelCreateResponse?, Error?) -> Void) -> Disposable {
        
        guard let data = try? payload.encode() else {
            completionHandler(nil, AirshipErrors.error("Unable to encode data."))
            return Disposable()
        }
        
        AirshipLogger.debug("Creating channel with: \(String(data:data, encoding: .utf8) ?? "")")

        let url = URL(string: "\(self.config.deviceAPIURL ?? "")\(self.path)")
        let request = Request(builderBlock: { [self] builder in
            builder.url = url
            builder.method = "POST"
            builder.username = config.appKey
            builder.password = config.appSecret
            builder.body = data
            builder.setValue("application/vnd.urbanairship+json; version=3;", header: "Accept")
            builder.setValue("application/json", header: "Content-Type")
        })

        return session.performHTTPRequest(request, completionHandler: { (data, response, error) in
            guard let response = response else {
                AirshipLogger.debug("Channel creation finished with error: \(error.debugDescription)")
                completionHandler(nil, error)
                return
            }

            AirshipLogger.debug("Channel creation finished with response: \(response)")

            let status = response.statusCode
            if (status == 200 || status == 201) {
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

                    let response = ChannelCreateResponse(status: status, channelID: channelID)
                    completionHandler(response, nil)
                } catch {
                    completionHandler(nil, error)
                }
            } else {
                let response = ChannelCreateResponse(status: status, channelID: nil)
                completionHandler(response, nil)
            }
        })
    }

    @objc
    @discardableResult
    public func updateChannel(withID channelID: String, withPayload payload: ChannelRegistrationPayload, completionHandler: @escaping (HTTPResponse?, Error?) -> Void) -> Disposable {
        guard let data = try? payload.encode() else {
            completionHandler(nil, AirshipErrors.error("Unable to encode data."))
            return Disposable()
        }
        
        AirshipLogger.debug("Updating channel with: \(String(data:data, encoding: .utf8) ?? "")")

        
        let channelLocation = "\(config.deviceAPIURL ?? "")\(self.path)\(channelID)"

        let request = Request(builderBlock: { [self] builder in
            builder.url = URL(string: channelLocation)
            builder.method = "PUT"
            builder.username = config.appKey
            builder.password = config.appSecret
            builder.body = data
            builder.setValue("application/vnd.urbanairship+json; version=3;", header: "Accept")
            builder.setValue("application/json", header: "Content-Type")
        })

        return session.performHTTPRequest(request, completionHandler: { (data, response, error) in
            guard (response != nil) else {
                AirshipLogger.debug("Channel update finished with error: \(error.debugDescription)")
                completionHandler(nil, error)
                return
            }

            AirshipLogger.debug("Channel update finished with response: \(response!)")
            completionHandler(HTTPResponse(status: response!.statusCode), nil)
        })
    }
}


/**
 * - Note: For internal use only. :nodoc:
 */
protocol ChannelAPIClientProtocol {
    @discardableResult
    func createChannel(withPayload payload: ChannelRegistrationPayload, completionHandler: @escaping (ChannelCreateResponse?, Error?) -> Void) -> Disposable
    @discardableResult
    func updateChannel(withID channelID: String, withPayload payload: ChannelRegistrationPayload, completionHandler: @escaping (HTTPResponse?, Error?) -> Void) -> Disposable
}

extension ChannelAPIClient : ChannelAPIClientProtocol {
    
}
