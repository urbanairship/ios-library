/* Copyright Airship and Contributors */

/// NOTE: For internal use only. :nodoc:
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

    @objc
    public let remoteDataInfo: RemoteDataInfo?


    public init(
        type: String,
        timestamp: Date,
        data: AirshipJSON,
        remoteDataInfo: RemoteDataInfo?
    ) {
        self.type = type
        self.timestamp = timestamp
        self._data = data
        self.remoteDataInfo = remoteDataInfo
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
            remoteDataInfo == other.remoteDataInfo
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
        result = 31 * result + self.remoteDataInfo.hashValue
        return result
    }

    public override var description: String {
        return "RemoteDataPayload(type=\(type), timestamp=\(timestamp), data=\(_data), remoteDataInfo=\(String(describing: remoteDataInfo)))"
    }
}
