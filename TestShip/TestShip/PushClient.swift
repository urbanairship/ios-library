/* Copyright 2017 Urban Airship and Contributors */

import AirshipKit

fileprivate func < <T : Comparable>(lhs: T?, rhs: T?) -> Bool {
  switch (lhs, rhs) {
  case let (l?, r?):
    return l < r
  case (nil, _?):
    return true
  default:
    return false
  }
}

fileprivate func > <T : Comparable>(lhs: T?, rhs: T?) -> Bool {
  switch (lhs, rhs) {
  case let (l?, r?):
    return l > r
  default:
    return rhs < lhs
  }
}

class PushClient: NSObject {

    let pushEndpoint: String = UAirship.shared().config.deviceAPIURL + "/api/push/"

    func pushPayload(payload:()->([String : Any]?)) {
        let customConfig: NSDictionary = UAirship.shared().config.customConfig as NSDictionary
        let appKey: String = UAirship.shared().config.appKey!
        var masterSecret: String = "";

        guard let payload = payload() else {
            print("pushPayload failed because of improperly formed payload")
            return
        }

        let request = NSMutableURLRequest(url: URL(string: UAirship.shared().config.deviceAPIURL + "/api/push/")!)

        if customConfig.value(forKey: "masterSecret") is String {
            masterSecret = customConfig.value(forKey: "masterSecret") as! String
        }

        let session = URLSession.shared

        request.httpMethod = "POST"

        let masterAuthString = "\(appKey):\(masterSecret)"
        let loginData = masterAuthString.data(using: String.Encoding.utf8)
        let base64Login:String! = (loginData?.base64EncodedString(options: NSData.Base64EncodingOptions(rawValue: 0)))!

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: payload, options:[])
        } catch let error {
            print("Push failed with generate request body with error: \(error)")
        }

        request.httpBody = request.httpBody!
        request.addValue("Basic \(base64Login!)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("application/vnd.urbanairship+json;version=3;", forHTTPHeaderField: "Accept")

        let immutableRequest = request as URLRequest
        let task = session.dataTask(with: immutableRequest) { (data, response, error) in
            print("Response: \(String(describing: response))")
            do {
                let json = try JSONSerialization.jsonObject(with: data!, options: .mutableLeaves) as? NSDictionary
                print("Received response:\(String(describing: json))");
            } catch let error {
                print("Could not parse response with error:\(error)")
            }
        }

        task.resume()
    }
}


