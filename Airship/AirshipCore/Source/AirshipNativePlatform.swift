/* Copyright Airship and Contributors */

public import SwiftUI

#if canImport(UIKit)
public import UIKit
public typealias AirshipNativeFont = UIFont
public typealias AirshipNativeColor = UIColor
#if !os(watchOS)
public typealias AirshipNativeViewController = UIViewController
public typealias AirshipNativeHostingController = UIHostingController
public typealias AirshipNativeViewRepresentable = UIViewRepresentable
#endif
#elseif canImport(AppKit)
public import AppKit
public typealias AirshipNativeFont = NSFont
public typealias AirshipNativeColor = NSColor
public typealias AirshipNativeViewController = NSViewController
public typealias AirshipNativeHostingController = NSHostingController
public typealias AirshipNativeViewRepresentable = NSViewRepresentable
#endif
