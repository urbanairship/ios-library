/* Copyright Airship and Contributors */

import Combine
import SwiftUI
import AirshipCore
import AirshipPreferenceCenter

struct AirshipDebugPreferenceCentersView: View {

    @StateObject
    private var viewModel = ViewModel()

    var body: some View {
        Form {
            ForEach(self.viewModel.identifiers, id: \.self) { identifier in
                CommonItems.navigationLink(
                    title: identifier,
                    route: .preferenceCentersSub(.preferenceCenter(identifier: identifier))
                )
            }
        }
        .navigationTitle("Preference Centers".localized())
    }

    @MainActor
    class ViewModel: ObservableObject {
        @Published private(set) var identifiers: [String] = []
        private var cancellable: AnyCancellable? = nil

        init() {
            if Airship.isFlying {
                self.cancellable = Airship.internalDebugManager
                    .preferenceFormsPublisher
                    .receive(on: RunLoop.main)
                    .sink { incoming in
                        self.identifiers = incoming.sorted()
                    }
            }
        }
    }
}

#Preview {
    AirshipDebugPreferenceCentersView()
}
