/* Copyright Airship and Contributors */

// NOTE: For internal use only. :nodoc:
@objc(UARemoteDataPayload)
public class RemoteDataPayload : NSObject {
    
    /// The payload type
    @objc
    public let type: String
    
    /// The timestamp of the most recent change to this data payload
    @objc
    public let timestamp: Date
    
    /// The actual data associated with this payload
    @objc
    public let data: [AnyHashable : Any]
    
    /// The metadata associated with this payload
    ///
    /// Contains important metadata such as locale.
    @objc
    public let metadata: [AnyHashable : Any]?

    @objc
    public init(type: String, timestamp: Date, data: [AnyHashable : Any], metadata: [AnyHashable : Any]?) {
        self.type = type
        self.timestamp = timestamp
        self.data = data
        self.metadata = metadata
        super.init()
    }
    
    public override func isEqual(_ other: Any?) -> Bool {
        guard let payload = other as? RemoteDataPayload else {
            return false
        }

        if (self === payload) {
            return true
        }

        return isEqual(to: payload)
    }

    private func isEqual(to other: RemoteDataPayload) -> Bool {
        guard type == other.type,
              timestamp == other.timestamp,
              data as NSDictionary == other.data as NSDictionary,
              metadata as NSDictionary? == other.metadata as NSDictionary? else {
            return false
        }
        
        return true
    }
    
    
    func hash() -> Int {
        var result = 1
        result = 31 * result + self.type.hashValue
        result = 31 * result + timestamp.hashValue
        result = 31 * result + (self.data as NSDictionary).hashValue
        result = 31 * result + ((self.metadata as NSDictionary?)?.hashValue ?? 0)
        return result
    }

    public override var description: String {
        get {
            return "RemoteDataPayload(type=\(type), timestamp = \(timestamp), data = \(data), metadata = \(metadata ?? [:])"
        }
    }
}
