/*
Copyright 2009-2015 Urban Airship Inc. All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:

1. Redistributions of source code must retain the above copyright notice, this
list of conditions and the following disclaimer.

2. Redistributions in binary form must reproduce the above copyright notice,
this list of conditions and the following disclaimer in the documentation
and/or other materials provided with the distribution.

THIS SOFTWARE IS PROVIDED BY THE URBAN AIRSHIP INC ``AS IS'' AND ANY EXPRESS OR
IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF
MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO
EVENT SHALL URBAN AIRSHIP INC OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT,
INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE
OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF
ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
*/

import UIKit
import AVFoundation
import AirshipKit

class PushHandler: NSObject, UAPushNotificationDelegate {

    var audioPlayer = AVAudioPlayer()

    func playNotificationSound(_ soundFilename: String) {

        let sound: NSString = NSString(string: soundFilename)
        let path = Bundle.main.path(forResource: sound.deletingPathExtension, ofType: sound.pathExtension)

        guard (path != nil) else {
            print("Received an alert with a sound that cannot be found the application bundle: \(soundFilename)")
            return
        }

        do {
            let url = URL(fileURLWithPath: path!)
            try audioPlayer = AVAudioPlayer(contentsOf: url)
            audioPlayer.prepareToPlay()
            audioPlayer.play()
        } catch {
            print("Couldn't load sound file");
        }

        print("Received a foreground alert with a sound: \(sound)");
    }

    func receivedForegroundNotification(_ notification: UANotificationContent, completionHandler: @escaping () -> Void) {
        print("Received a notification while the app was already in the foreground")

        let alertController: UIAlertController = UIAlertController()

        alertController.message = notification.alertBody
        if let alertTitle = notification.alertTitle {
            alertController.title = alertTitle
        } else {
            alertController.title = NSLocalizedString("UA_Notification_Title", tableName: "UAPushUI", comment: "System Push Settings Label")
        }

        let cancelAction = UIAlertAction(title: "OK", style: UIAlertActionStyle.default, handler: nil)
        alertController.addAction(cancelAction)

        let topController = UIApplication.shared.keyWindow!.rootViewController! as UIViewController
        alertController.popoverPresentationController?.sourceView = topController.view

        topController.present(alertController, animated:true, completion:nil)

        completionHandler()
    }

    func receivedBackgroundNotification(_ notification: UANotificationContent, completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        print("The application was started in the background from a user notification")
        completionHandler(UIBackgroundFetchResult.noData)
    }

}
