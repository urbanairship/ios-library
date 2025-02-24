/* Copyright Airship and Contributors */

import AirshipNotificationServiceExtension

class NotificationService: UANotificationServiceExtension {

    /// Overrides config to log everyting publically
    override var airshipConfig: AirshipExtensionConfig  {
        AirshipExtensionConfig(
            logLevel: .verbose,
            logHandler: .publicLogger
        )
    }
    
}
