/* Copyright Airship and Contributors */

import Combine
import SwiftUI

#if canImport(AirshipCore)
import AirshipCore
#elseif canImport(AirshipKit)
import AirshipKit
#endif

struct AirshipDebugExperimentsView: View {

    @StateObject
    private var viewModel = ViewModel()

    var body: some View {
        Form {
            Section(header: Text("")) {
                ForEach(self.viewModel.payloads, id: \.self) { payload in
                    VStack(alignment: .leading) {
                        Text(parseID(payload: payload))
                    }
                }
            }
        }
        .navigationTitle("Experiments".localized())
    }

    func parseID(payload: [String: AnyHashable]) -> String {
        return payload["experiment_id"] as? String ?? "MISSING_ID"
    }

    @MainActor
    class ViewModel: ObservableObject {
        @Published private(set) var payloads: [[String: AnyHashable]] =
            []
        private var cancellable: AnyCancellable? = nil

        init() {
            if Airship.isFlying {
                self.cancellable = Airship.internalDebugManager
                    .experimentsPublisher
                    .receive(on: RunLoop.main)
                    .sink { incoming in
                        self.payloads = incoming
                    }
            }
        }
    }
}

#Preview {
    AirshipDebugExperimentsView()
}
