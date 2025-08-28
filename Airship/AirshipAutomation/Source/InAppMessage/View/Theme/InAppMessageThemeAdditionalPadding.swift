/* Copyright Airship and Contributors */


import SwiftUI


extension InAppMessageTheme {
    struct AdditionalPadding: Decodable {
        var top: CGFloat?
        var leading: CGFloat?
        var trailing: CGFloat?
        var bottom: CGFloat?
    }
}


extension EdgeInsets {
    mutating func add(_ additionalPadding: InAppMessageTheme.AdditionalPadding?) {
        guard let additionalPadding else { return }
        self.top =  self.top + (additionalPadding.top ?? 0)
        self.leading = self.leading + (additionalPadding.leading ?? 0)
        self.trailing = self.trailing + (additionalPadding.trailing ?? 0)
        self.bottom = self.bottom + (additionalPadding.bottom ?? 0)
    }
}
