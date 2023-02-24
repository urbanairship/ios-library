/* Copyright Airship and Contributors */

// NOTE: For internal use only. :nodoc:
@objc(UARemoteDataPayload)
public final class RemoteDataPayload: NSObject, Sendable {

    /// The payload type
    @objc
    public let type: String

    /// The timestamp of the most recent change to this data payload
    @objc
    public let timestamp: Date

    private let _data: AirshipJSON
    
    /// The actual data associated with this payload
    @objc
    public var data: [AnyHashable: Any] {
        return _data.unWrap() as? [AnyHashable: Any] ?? [:]
    }

    
    public let _metadata: AirshipJSON
    
    /// The metadata associated with this payload
    ///
    /// Contains important metadata such as locale.
    @objc(metadata)
    public var metadata: [AnyHashable: Any]? {
        return _metadata.unWrap() as? [AnyHashable: Any]
    }

    @objc
    public init(
        type: String,
        timestamp: Date,
        data: [AnyHashable: Any],
        metadata: [AnyHashable: Any]?
    ) {
        self.type = type
        self.timestamp = timestamp
        self._data = (try? AirshipJSON.wrap(data)) ?? AirshipJSON.null
        self._metadata = (try? AirshipJSON.wrap(metadata)) ?? AirshipJSON.null
        super.init()
    }

    public override func isEqual(_ other: Any?) -> Bool {
        guard let payload = other as? RemoteDataPayload else {
            return false
        }

        if self === payload {
            return true
        }

        return isEqual(to: payload)
    }

    private func isEqual(to other: RemoteDataPayload) -> Bool {
        guard
            type == other.type,
            timestamp == other.timestamp,
            _data == other._data,
            _metadata == other._metadata
        else {
            return false
        }

        return true
    }

    func hash() -> Int {
        var result = 1
        result = 31 * result + self.type.hashValue
        result = 31 * result + timestamp.hashValue
        result = 31 * result + self._data.hashValue
        result = 31 * result + self._metadata.hashValue
        return result
    }

    public override var description: String {
        return
            "RemoteDataPayload(type=\(type), timestamp = \(timestamp), data = \(_data), metadata = \(_metadata)"
    }
}
