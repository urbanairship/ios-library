/* Copyright Airship and Contributors */

import SwiftUI

// MARK: Background
struct BackgroundShape: View {
    var color: Color
    var body: some View {
        Rectangle()
            .fill(color)
            .cornerRadius(10)
            .shadow(radius: 5)
    }
}
