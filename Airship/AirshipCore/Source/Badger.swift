// Copyright Airship and Contributors

import Foundation
import UIKit

protocol Badger {
    var applicationIconBadgeNumber: Int { get set }
}

extension UIApplication: Badger {}
