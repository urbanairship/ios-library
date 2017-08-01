/* Copyright 2017 Urban Airship and Contributors */

import UIKit
import AirshipKit

class RegistrationDelegate: NSObject, UARegistrationDelegate {

    var registrationSucceeded:(_ channelID: String, _ deviceToken: String)->Void = {_ in}
    var apnsRegistrationSucceeded:(_ deviceToken: Data)->Void = {_ in}

    func registrationSucceeded(forChannelID channelID: String, deviceToken: String) {
        registrationSucceeded(channelID, deviceToken)
    }

    func apnsRegistrationSucceeded(withDeviceToken deviceToken: Data) {
        apnsRegistrationSucceeded(deviceToken)
    }
}
