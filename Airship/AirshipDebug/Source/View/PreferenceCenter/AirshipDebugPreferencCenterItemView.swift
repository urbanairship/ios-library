/* Copyright Airship and Contributors */

import Foundation
import SwiftUI
import Combine
import AirshipCore
import AirshipPreferenceCenter

struct AirshipDebugPreferencCenterItemView: View {

    private let preferenceCenterID: String

    @State private var title: String? = nil

    init(preferenceCenterID: String) {
        self.preferenceCenterID = preferenceCenterID
    }

    @ViewBuilder
    public var body: some View {
        PreferenceCenterContent(
            preferenceCenterID: preferenceCenterID,
            onPhaseChange: { phase in
                guard case .loaded(let state) = phase else { return }

                let title = state.config.display?.title
                if let title, title.isEmpty == false {
                    self.title = title
                }
            }
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .navigationTitle(self.title ?? preferenceCenterID)
    }
}
