import Foundation

@objc(UARemoteDataInfo)
public final class RemoteDataInfo: NSObject, Sendable, Codable, NSCopying {
    let url: URL

    let lastModifiedTime: String?

    @objc
    public let source: RemoteDataSource

    @objc
    public let contactID: String?

    init(url: URL, lastModifiedTime: String?, source: RemoteDataSource, contactID: String? = nil) {
        self.url = url
        self.lastModifiedTime = lastModifiedTime
        self.source = source
        self.contactID = contactID
    }

    public override func isEqual(_ object: Any?) -> Bool {
        guard
            let other = object as? RemoteDataInfo,
            url == other.url,
            lastModifiedTime == other.lastModifiedTime,
            source == other.source
        else {
            return false
        }

        return true
    }

    func hash() -> Int {
        var result = 1
        result = 31 * result + self.url.hashValue
        result = 31 * result + self.lastModifiedTime.hashValue
        result = 31 * result + self.source.hashValue
        return result
    }

    public override var description: String {
        return "RemoteDataInfo(url=\(url), lastModifiedTime=\(String(describing: lastModifiedTime)), source=\(source)), contactID=\(String(describing: contactID))"
    }

    private static let decoder = JSONDecoder()
    private static let encoder = JSONEncoder()

    class func fromJSON(data: Data) throws -> RemoteDataInfo {
        return try RemoteDataInfo.decoder.decode(RemoteDataInfo.self, from: data)
    }

    @objc
    public class func fromJSON(string: String) throws -> RemoteDataInfo {
        guard let data = string.data(using: .utf8) else {
            throw AirshipErrors.error("Invalid json string: \(string)")
        }
        return try fromJSON(data: data)
    }

    func toEncodedJSONData() throws -> Data {
        return try RemoteDataInfo.encoder.encode(self)
    }

    @objc
    public func toEncodedJSONString() throws -> String {
        return try String(decoding: toEncodedJSONData(), as: UTF8.self)
    }
    
    public func copy(with zone: NSZone? = nil) -> Any {
        return RemoteDataInfo(url: url, lastModifiedTime: lastModifiedTime, source: source)
    }
}
