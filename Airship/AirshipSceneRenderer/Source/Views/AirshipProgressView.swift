/* Copyright Airship and Contributors */

import Foundation
import SwiftUI

/// Progress view
struct AirshipProgressView: View {

    @State private var isVisible: Bool = false

    var body: some View {
        ProgressView()
            // Every loading state in the renderer goes through this view; UI tests wait for
            // the identifier to disappear before taking a screenshot.
            .accessibilityIdentifier("thomas:loading")
    }
}

