/* Copyright Airship and Contributors */

import Foundation

#if canImport(AirshipCore)
    import AirshipCore
#endif

class PreferenceCenterDecoder {
    private static let decoder: JSONDecoder = {
        var decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    class func decodeConfig(object: [AnyHashable: Any]) throws
        -> PrefrenceCenterResponse
    {
        let data = try JSONSerialization.data(
            withJSONObject: object,
            options: []
        )
        return try decodeConfig(data: data)
    }

    class func decodeConfig(data: Data) throws -> PrefrenceCenterResponse {
        return try self.decoder.decode(PrefrenceCenterResponse.self, from: data)
    }
}
