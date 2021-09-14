
/**
 * - Note: For internal use only. :nodoc:
 */
@objc(UAEventAPIResponse)
public class EventAPIResponse : HTTPResponse {
    @objc
    public let maxTotalDBSize: NSNumber?

    @objc
    public let maxBatchSize: NSNumber?

    @objc
    public let minBatchInterval: NSNumber?

    @objc
    public init(status: Int, maxTotalDBSize: NSNumber?, maxBatchSize: NSNumber?, minBatchInterval: NSNumber?) {
        self.maxTotalDBSize = maxTotalDBSize
        self.maxBatchSize = maxBatchSize
        self.minBatchInterval = minBatchInterval
        super.init(status: status)
    }
}
