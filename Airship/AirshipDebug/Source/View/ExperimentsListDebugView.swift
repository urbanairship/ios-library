/* Copyright Airship and Contributors */

import Combine
public import SwiftUI

#if canImport(AirshipCore)
import AirshipCore
#elseif canImport(AirshipKit)
import AirshipKit
#endif

public struct ExperimentsListsDebugView: View {

    @StateObject
    private var viewModel = ViewModel()

    public init() {}

    public var body: some View {
        Form {
            Section(header: Text("")) {
                List(self.viewModel.payloads, id: \.self) { payload in
                    NavigationLink(
                        destination: AirshipJSONDetailsView(
                            payload: AirshipJSON.wrapSafe(payload),
                            title: parseID(payload: payload)
                        )
                    ) {
                        VStack(alignment: .leading) {
                            Text(parseID(payload: payload))
                        }
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
                self.cancellable = Airship.debugManager
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
    ExperimentsListsDebugView()
}
