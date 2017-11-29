/* Copyright 2017 Urban Airship and Contributors */

import UIKit
import AirshipKit

/*
 * The Test Ship registration delegate.
 */
class RegistrationDelegate: NSObject, UARegistrationDelegate {

    var forwardDelegate:UARegistrationDelegate?

    var registrationSucceeded:(_ channelID: String, _ deviceToken: String)->Void = {_,_  in}

    func registrationSucceeded(forChannelID channelID: String, deviceToken: String) {
        registrationSucceeded(channelID, deviceToken)

        guard let delegate = forwardDelegate else { return }

        if delegate.responds(to: #selector(UARegistrationDelegate.registrationSucceeded)) {
            forwardDelegate?.registrationSucceeded!(forChannelID: channelID, deviceToken: deviceToken)
        }
    }

    func registrationFailed() {
        guard let delegate = forwardDelegate else { return }

        if delegate.responds(to: #selector(UARegistrationDelegate.registrationFailed)) {
            forwardDelegate?.registrationFailed!()
        }
    }

    func notificationRegistrationFinished(options: UANotificationOptions = [], categories: Set<AnyHashable>) {
        guard let delegate = forwardDelegate else { return }

        if delegate.responds(to: #selector(UARegistrationDelegate.notificationRegistrationFinished(options:categories:))) {
            forwardDelegate?.notificationRegistrationFinished!(options: options, categories: categories)
        }
    }

    func notificationAuthorizedOptionsDidChange(_ options: UANotificationOptions = []) {
        guard let delegate = forwardDelegate else { return }

        if delegate.responds(to: #selector(UARegistrationDelegate.notificationAuthorizedOptionsDidChange(_:))) {
            forwardDelegate?.notificationAuthorizedOptionsDidChange!(options)
        }
    }

    func apnsRegistrationSucceeded(withDeviceToken deviceToken: Data) {
        guard let delegate = forwardDelegate else { return }

        if delegate.responds(to: #selector(UARegistrationDelegate.apnsRegistrationSucceeded(withDeviceToken:))) {
            forwardDelegate?.apnsRegistrationSucceeded!(withDeviceToken: deviceToken)
        }
    }

    func apnsRegistrationFailedWithError(_ error: Error) {
        guard let delegate = forwardDelegate else { return }

        if delegate.responds(to: #selector(UARegistrationDelegate.apnsRegistrationFailedWithError(_:))) {
            forwardDelegate?.apnsRegistrationFailedWithError!(error)
        }
    }
}
