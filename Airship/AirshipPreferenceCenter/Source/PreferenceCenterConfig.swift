/* Copyright Airship and Contributors */

#if canImport(AirshipCore)
import AirshipCore
#endif

@objc(UAPreferenceCenterConfig)
protocol PreferenceCenterConfig {
    var preferenceCenterId: String { get }
}
