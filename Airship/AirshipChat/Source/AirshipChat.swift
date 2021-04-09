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
@available(iOS 13.0, *)
@objc(UAirshipChat)
public class AirshipChat : UAComponent {

    /**
     * The default conversation.
     */
    @objc
    public let conversation : ConversationProtocol

    init(dataStore: UAPreferenceDataStore, config: UARuntimeConfig, channel: UAChannel) {
        self.conversation = Conversation(dataStore: dataStore,
                                         chatConfig: config,
                                         channel: channel)
        super.init(dataStore: dataStore)

        AirshipLogger.info("AirshipChat initialized")
    }
}
