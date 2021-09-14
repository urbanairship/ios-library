/* Copyright Airship and Contributors */

/**
 * - Note: For internal use only. :nodoc:
 */
@objc(UAEventAPIClient)
public class EventAPIClient : NSObject, EventAPIClientProtocol {
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
    public func uploadEvents(_ events: [AnyHashable], headers: [String : String], completionHandler: @escaping (EventAPIResponse?, Error?) -> Void) -> Disposable {

        var body : Data?
        do {
            body = try JSONUtils.data(events, options: [])
        } catch {
            completionHandler(nil, error)
            return Disposable()
        }

        let request = Request(builderBlock: { builder in
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
            let maxTotal = EventAPIClient.parseNumber(headers?["X-UA-Max-Total"] as? String)
            let maxBatch = EventAPIClient.parseNumber(headers?["X-UA-Max-Batch"] as? String)
            let minBatchInterval = EventAPIClient.parseNumber(headers?["X-UA-Min-Batch-Interval"] as? String)

            let eventAPIResponse = EventAPIResponse(
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
