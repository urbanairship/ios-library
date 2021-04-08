/* Copyright Airship and Contributors */

#if canImport(AirshipCore)
import AirshipCore
#elseif !COCOAPODS && canImport(Airship)
import Airship
#endif

protocol AirshipChannel {
    var identifier: String? { get }
}

extension UAChannel : AirshipChannel {}
