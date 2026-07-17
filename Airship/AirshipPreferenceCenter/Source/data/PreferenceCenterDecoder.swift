/* Copyright Airship and Contributors */

import Foundation

@_spi(AirshipInternal) import AirshipBasement

import AirshipCore

final class PreferenceCenterDecoder {
    class func decodeConfig(data: Data) throws -> PreferenceCenterConfig {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .airshipISO8601
        return try decoder.decode(PreferenceCenterConfig.self, from: data)
    }
}
