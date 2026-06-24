/* Copyright Airship and Contributors */

import Foundation

internal extension Int {
    func airshipLocalizedForVoiceOver() -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .spellOut
        return formatter.string(from: NSNumber(value: self)) ?? String(self)
    }
}
