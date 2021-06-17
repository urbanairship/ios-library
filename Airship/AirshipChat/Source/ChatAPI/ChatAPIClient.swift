/* Copyright Airship and Contributors */

#if canImport(AirshipCore)
import AirshipCore
#endif


import Foundation

enum ChatAPIClientError: Error {
    case missingURL
}

class ChatAPIClient : ChatAPIClientProtocol {
    private let chatConfig: ChatConfig
    private let session: HTTPRequestSession

    init(chatConfig: ChatConfig, session: HTTPRequestSession = UARequestSession.sharedNSURLSession()) {
        self.chatConfig = chatConfig
        self.session = session
    }

    func createUVP(channelID: String, callback: @escaping (UVPResponse?, Error?) -> ()) {
        guard let url = createURL(channelID) else {
            callback(nil, ChatAPIClientError.missingURL)
            return
        }

        var uvpUrlRequest = URLRequest(url: url)
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

    private func createURL(_ channelID: String) -> URL? {
        guard let base = self.chatConfig.chatURL else {
            return nil
        }

        let urlString = "\(base)/api/UVP?channelId=\(channelID)&appKey=\(self.chatConfig.appKey)&platform=iOS"

        return URL(string: urlString)
    }
}
