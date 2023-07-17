/* Copyright Airship and Contributors */

import Combine
import SwiftUI

#if canImport(AirshipCore)
import AirshipCore
#elseif canImport(AirshipKit)
import AirshipKit
#endif

public struct FeatureFlagListDebugView: View {

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
                            title: parseName(payload: payload)
                        )
                    ) {
                        VStack(alignment: .leading) {
                            Text(parseName(payload: payload))
                            Text(parseID(payload: payload))
                        }
                    }
                }
            }
        }
        .navigationTitle("Feature Flags".localized())
    }

    func parseID(payload: [String: AnyHashable]) -> String {
        return payload["flag_id"] as? String ?? "MISSING_ID"
    }

    func parseName(payload: [String: AnyHashable]) -> String {
        let flag = payload["flag"] as? [String: AnyHashable]
        return flag?["name"] as? String ?? "MISSING_NAME"
    }

    class ViewModel: ObservableObject {
        @Published private(set) var payloads: [[String: AnyHashable]] =
            []
        private var cancellable: AnyCancellable? = nil

        init() {
            if Airship.isFlying {
                self.cancellable = AirshipDebugManager.shared
                    .featureFlagPublisher
                    .receive(on: RunLoop.main)
                    .sink { incoming in
                        self.payloads = incoming
                    }
            }
        }
    }
}

