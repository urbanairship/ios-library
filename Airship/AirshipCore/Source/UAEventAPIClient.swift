/* Copyright Airship and Contributors */

/**
 * @note For internal use only. :nodoc:
 */
@objc
public class UAEventAPIClient : NSObject, EventAPIClientProtocol {
    private let config: RuntimeConfig
    private let session: UARequestSession

    @objc
    public init(config: RuntimeConfig, session: UARequestSession) {
        self.config = config
        self.session = session
        super.init()
    }

    @objc
    public convenience init(config: RuntimeConfig) {
        self.init(config: config, session: UARequestSession(config: config))
    }

    @objc
    @discardableResult
    public func uploadEvents(_ events: [AnyHashable], headers: [String : String], completionHandler: @escaping (UAEventAPIResponse?, Error?) -> Void) -> UADisposable {

        var body : Data?
        do {
            body = try JSONUtils.data(events, options: [])
        } catch {
            completionHandler(nil, error)
            return UADisposable()
        }

        let request = UARequest(builderBlock: { builder in
            builder.url = URL(string: "\(self.config.analyticsURL ?? "")\("/warp9/")")
            builder.method = "POST"
            builder.compressBody = true
            builder.body = body

            builder.addHeaders(headers)
            builder.setValue("application/json", header: "Content-Type")
            builder.setValue("\(Date().timeIntervalSince1970)", header: "X-UA-Sent-At")
        })

        AirshipLogger.trace("Sending to server: \(config.analyticsURL ?? "")")
        AirshipLogger.trace("Sending analytics headers: \(headers)")
        AirshipLogger.trace("Sending analytics events: \(events)")

        // Perform the upload
        return session.performHTTPRequest(request, completionHandler: { (data, response, error) in
            guard (response != nil) else {
                completionHandler(nil, error)
                return
            }

            let headers = response?.allHeaderFields
            let maxTotal = UAEventAPIClient.parseNumber(headers?["X-UA-Max-Total"] as? String)
            let maxBatch = UAEventAPIClient.parseNumber(headers?["X-UA-Max-Batch"] as? String)
            let minBatchInterval = UAEventAPIClient.parseNumber(headers?["X-UA-Min-Batch-Interval"] as? String)

            let eventAPIResponse = UAEventAPIResponse(
                status: response?.statusCode ?? 0,
                maxTotalDBSize: maxTotal,
                maxBatchSize: maxBatch,
                minBatchInterval: minBatchInterval)
            completionHandler(eventAPIResponse, nil)
        })
    }

    private static func parseNumber(_ value: String?) -> NSNumber? {
        let int = value == nil ? nil : Int(value!)
        if (int != nil) {
            return NSNumber(value: int!)
        }
        return nil
    }
}
