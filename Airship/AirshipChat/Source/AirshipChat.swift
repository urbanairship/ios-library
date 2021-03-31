/* Copyright Airship and Contributors */

import Foundation;

#if canImport(AirshipCore)
import AirshipCore
#elseif !COCOAPODS && canImport(Airship)
import Airship
#endif

/**
 * Airship chat module.
 */
@objc(UAirshipChat)
public class AirshipChat : UAComponent {

    private var channel: UAChannel
    private var push: UAPush

    init(dataStore: UAPreferenceDataStore, channel: UAChannel, push: UAPush) {
        self.channel = channel
        self.push = push
        super.init(dataStore: dataStore)
        AirshipLogger.info("AirshipChat initialized")
    }
}
