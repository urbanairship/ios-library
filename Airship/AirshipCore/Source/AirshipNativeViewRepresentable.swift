/* Copyright Airship and Contributors */

public import SwiftUI

#if os(macOS)
/// A platform-agnostic view representable that bridges to NSViewRepresentable on macOS.
public typealias AirshipNativeViewRepresentable = NSViewRepresentable
#elseif !os(watchOS)
/// A platform-agnostic view representable that bridges to UIViewRepresentable on iOS, tvOS, and visionOS.
public typealias AirshipNativeViewRepresentable = UIViewRepresentable
#endif
