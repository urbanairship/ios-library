// Copyright Airship and Contributors

import Foundation
import UIKit
#if os(watchOS)
import WatchKit
#endif

protocol Badger {
#if !os(watchOS)
    var applicationIconBadgeNumber: Int { get set }
#endif
}

#if !os(watchOS)

extension UIApplication: Badger {}

#else

extension WKExtension: Badger {}

#endif
