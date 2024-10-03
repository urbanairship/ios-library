/* Copyright Airship and Contributors */

import Foundation
import SwiftUI

extension ProgressView {
    @ViewBuilder
    func appearanceTint() -> some View {
        if let color = UIRefreshControl.appearance().tintColor {
            let color = Color(color)
            if #available(iOS 15.0, *) {
                self.tint(color)
            }
        } else {
            self
        }
    }
}
