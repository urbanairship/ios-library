/* Copyright Airship and Contributors */



#if canImport(AirshipCore)
import AirshipCore
#endif
class PreferenceCenterDecoder {
    private static let decoder: JSONDecoder = {
        var decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    class func decodeConfig(data: Data) throws -> PreferenceCenterConfig {
        return try self.decoder.decode(PreferenceCenterConfig.self, from: data)
    }
}
