/* Copyright Airship and Contributors */

import Combine
import SwiftUI

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
                        destination: ExperemintsDetailsView(
                            payload: payload,
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

    class ViewModel: ObservableObject {
        @Published private(set) var payloads: [[String: AnyHashable]] =
            []
        private var cancellable: AnyCancellable? = nil

        init() {
            if Airship.isFlying {
                self.cancellable = AirshipDebugManager.shared
                    .experimentsPublisher
                    .receive(on: RunLoop.main)
                    .sink { incoming in
                        self.payloads = incoming
                    }
            }
        }
    }
}

private struct ExperemintsDetailsView: View {
    let payload: [String: AnyHashable]
    let title: String

    @ViewBuilder
    var body: some View {
        let description = try? JSONUtils.string(
            payload,
            options: .prettyPrinted
        )
        Form {
            Section(header: Text("Details".localized())) {
                Text(description ?? "ERROR!")
            }
        }
        .navigationTitle(title)
    }
}
