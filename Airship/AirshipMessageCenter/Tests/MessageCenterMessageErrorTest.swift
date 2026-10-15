/* Copyright Airship and Contributors */

import Testing
@testable import AirshipMessageCenter

struct MessageCenterMessageErrorTest {

    @Test
    func localizedDescriptionKeys() {
        #expect(MessageCenterMessageError.messageGone.localizedDescriptionKey == "ua_mc_no_longer_available")
        #expect(MessageCenterMessageError.unsupportedOnDevice.localizedDescriptionKey == "ua_mc_unsupported_on_device")
        #expect(MessageCenterMessageError.failedToFetchMessage.localizedDescriptionKey == "ua_mc_failed_to_load")
        #expect(MessageCenterMessageError.messageLoadFailed.localizedDescriptionKey == "ua_mc_failed_to_load")
    }

    @Test
    func fromPreservesMessageCenterErrors() {
        #expect(MessageCenterMessageError.from(MessageCenterMessageError.unsupportedOnDevice) == .unsupportedOnDevice)
        #expect(MessageCenterMessageError.from(MessageCenterMessageError.messageGone) == .messageGone)
    }

    @Test
    func fromMapsOtherErrorsToLoadFailed() {
        struct Other: Error {}
        #expect(MessageCenterMessageError.from(Other()) == .messageLoadFailed)
    }
}
