/* Copyright Airship and Contributors */

#if canImport(AirshipCore)
import AirshipCore
#elseif !COCOAPODS && canImport(Airship)
import Airship
#endif

import Foundation

class ChatAPIClient : ChatAPIClientProtocol {
    private let url = "https://rb2socketscontactstest.replybuy.net/api/UVP"
    private let session: HTTPRequestSession

    init(session: HTTPRequestSession = UARequestSession.sharedNSURLSession()) {
        self.session = session
    }

    func createUVP(appKey: String, channelID: String, callback: @escaping (UVPResponse?, Error?) -> ()) {
        let requestURL = URL(string:self.url + "?channelId=" + channelID + "&appKey=" + appKey + "&platform=iOS")
        var uvpUrlRequest = URLRequest(url: requestURL!)
        uvpUrlRequest.httpMethod = "GET"
        uvpUrlRequest.addValue("application/json", forHTTPHeaderField: "Content-Type")
        uvpUrlRequest.addValue("application/json", forHTTPHeaderField: "Accept")

        session.performHTTPDataTask(uvpUrlRequest) { (data, response, error) in
            guard (response != nil) else {
                callback(nil, error)
                return
            }

            if (response!.statusCode == 200) {
                let parsedResponse = try? JSONSerialization.jsonObject(with: data!,
                                                                       options: []) as? [String: Any]

                let uvp = parsedResponse?["uvp"] as? String
                guard uvp != nil else {
                    callback(nil, NSError.airshipParseError(withMessage: "Failed to parse UVP response"))
                    return
                }
                callback(UVPResponse(status: UInt(response!.statusCode), uvp: uvp), nil)
            } else {
                callback(UVPResponse(status: UInt(response!.statusCode), uvp: nil), nil)
            }
        }
    }
}
