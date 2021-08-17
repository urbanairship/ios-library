/* Copyright Airship and Contributors */

#if canImport(AirshipCore)
import AirshipCore
#endif


protocol AirshipChannel {
    var identifier: String? { get }
}

extension Channel : AirshipChannel {}

