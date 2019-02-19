/* Copyright 2010-2019 Urban Airship and Contributors */

import Foundation

/**
 * This file contains utility function for the IAA debug views.
 */
func descriptionForColor(_ color : UIColor?) -> String {
    if (color == nil) {
        return "ua_color_default".localized()
    } else {
        return "\(color!)"
    }
}

