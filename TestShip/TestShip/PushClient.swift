/* Copyright 2010-2019 Urban Airship and Contributors */

import AirshipKit

/*
 * The Test Ship push client for making test push requests.
 */
class PushClient: NSObject {

    let pushEndpoint: String = "https://go.urbanairship.com/api/push/"

    /*
     * Makes an HTTP request the push endpoint to send the specified payload.
     */
    func pushPayload(payload:()->([String : Any]?)) {
        let customConfig: NSDictionary = UAirship.shared().config.customConfig as NSDictionary
        let appKey: String = UAirship.shared().config.appKey!
        var masterSecret: String = "";

        guard let payload = payload() else {
            print("pushPayload failed because of improperly formed payload")
            return
        }

        let request = NSMutableURLRequest(url: URL(string: pushEndpoint)!)

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


