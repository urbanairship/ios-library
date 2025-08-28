/* Copyright Airship and Contributors */



/// NOTE: For internal use only. :nodoc:
public struct RemoteDataPayload: Sendable, Equatable, Hashable {

    /// The payload type
    public let type: String

    /// The timestamp of the most recent change to this data payload
    public let timestamp: Date

    /// The actual data associated with this payload
    public let data: AirshipJSON

    public let remoteDataInfo: RemoteDataInfo?

    public init(
        type: String,
        timestamp: Date,
        data: AirshipJSON,
        remoteDataInfo: RemoteDataInfo?
    ) {
        self.type = type
        self.timestamp = timestamp
        self.data = data
        self.remoteDataInfo = remoteDataInfo
    }
}

public extension RemoteDataPayload {
    func data(key: String) -> AnyHashable? {
        guard case .object(let map) = self.data else { return nil }
        return map[key]?.unWrap()
    }
}
