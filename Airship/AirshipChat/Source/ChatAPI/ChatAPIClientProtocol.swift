/* Copyright Airship and Contributors */

#if canImport(AirshipCore)
import AirshipCore
#endif


import Foundation

struct UVPResponse {
    let status: UInt
    let uvp: String?
}

protocol ChatAPIClientProtocol {
    func createUVP(channelID: String, callback: @escaping (UVPResponse?, Error?) -> ())
}
