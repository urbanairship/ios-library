import Foundation

/// NOTE: For internal use only. :nodoc:
public struct RemoteDataInfo: Sendable, Codable, Equatable, Hashable {
    public let url: URL
    public let lastModifiedTime: String?
    public let source: RemoteDataSource
    public let contactID: String?

    public init(url: URL, lastModifiedTime: String?, source: RemoteDataSource, contactID: String? = nil) {
        self.url = url
        self.lastModifiedTime = lastModifiedTime
        self.source = source
        self.contactID = contactID
    }

    private static let decoder = JSONDecoder()
    private static let encoder = JSONEncoder()

    static func fromJSON(data: Data) throws -> RemoteDataInfo {
        return try RemoteDataInfo.decoder.decode(RemoteDataInfo.self, from: data)
    }

    func toEncodedJSONData() throws -> Data {
        return try RemoteDataInfo.encoder.encode(self)
    }
}
