/* Copyright Airship and Contributors */

import AirshipCore
import SwiftUI

struct LayoutsList: View {

    let layouts: [LayoutFile]

    let onOpen: @MainActor (LayoutFile) -> Void

    init(
        layouts: [LayoutFile],
        onOpen: @escaping @MainActor (LayoutFile) -> Void
    ) {
        self.onOpen = onOpen
        self.layouts = layouts
    }

    var body: some View {
        List {
            ForEach(self.layouts, id: \.self) { layout in
                Button(layout.fileName) {
                    onOpen(layout)
                }
            }
        }
    }
}

