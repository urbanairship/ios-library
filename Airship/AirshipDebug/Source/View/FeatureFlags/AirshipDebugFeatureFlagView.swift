/* Copyright Airship and Contributors */

import Combine
import SwiftUI
import AirshipCore
import AirshipFeatureFlags

struct AirshipDebugFeatureFlagView: View {

    @StateObject
    private var viewModel = ViewModel()

    var body: some View {
        Form {
            Section {
                ForEach(self.viewModel.entries, id: \.self) { name in
                    CommonItems.navigationLink(
                        title: name,
                        route: .featureFlagsSub(.featureFlagDetails(name: name))
                    )
                }
            }
        }
        .navigationTitle("Feature Flags".localized())
    }

    @MainActor
    class ViewModel: ObservableObject {
        @Published private(set) var entries: [String] = []
        private var cancellable: AnyCancellable? = nil

        init() {
            if Airship.isFlying {
                self.cancellable = Airship.internalDebugManager
                    .featureFlagPublisher
                    .receive(on: RunLoop.main)
                    .map { result in
                        return result.compactMap { element in
                            let flag = element["flag"] as? [String : AnyHashable]
                            return flag?["name"] as? String
                        }
                    }
                    .sink { incoming in
                        self.entries = Array(Set(incoming)).sorted()
                    }
            }
        }
    }
}

#Preview {
    AirshipDebugFeatureFlagView()
}
