/* Copyright Airship and Contributors */

import Foundation

class Occurrence {
    let parentConstraintID: String
    let timestamp: Date
    
    init(
        withParentConstraintID parentConstraintID: String,
        timestamp: Date
    ) {
        self.parentConstraintID = parentConstraintID
        self.timestamp = timestamp
    }
}
