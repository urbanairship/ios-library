/* Copyright Airship and Contributors */

import Combine
public import SwiftUI

#if canImport(AirshipCore)
import AirshipCore
#elseif canImport(AirshipKit)
import AirshipKit
#endif

public struct InAppAutomationListDebugView: View {

    @StateObject
    private var viewModel = ViewModel()

    public init() {}
    
    public var body: some View {
        Form {
            Section(header: Text("")) {
                List(self.viewModel.messagePayloads, id: \.self) { payload in
                    let title = parseTitle(payload: payload)
                    NavigationLink(
                        destination: AirshipJSONDetailsView(
                            payload: AirshipJSON.wrapSafe(payload),
                            title: title
                        )
                    ) {
                        VStack(alignment: .leading) {
                            Text(title)
                            Text(parseID(payload: payload))
                        }
                    }
                }
            }
        }
        .navigationTitle("In-App Automations".localized())
    }

    func parseTitle(payload: [String: AnyHashable]) -> String {
        let message = payload["message"] as? [String: AnyHashable]
        return message?["name"] as? String ?? parseType(payload: payload)
    }

    func parseType(payload: [String: AnyHashable]) -> String {
        return payload["type"] as? String ?? "Unknown"
    }

    func parseID(payload: [String: AnyHashable]) -> String {
        return payload["id"] as? String ?? "MISSING_ID"
    }

    @MainActor
    class ViewModel: ObservableObject {
        @Published private(set) var messagePayloads: [[String: AnyHashable]] =
            []
        private var cancellable: AnyCancellable? = nil

        init() {
            if Airship.isFlying {
                self.cancellable = Airship.debugManager
                    .inAppAutomationsPublisher
                    .receive(on: RunLoop.main)
                    .sink { incoming in
                        self.messagePayloads = incoming
                    }
            }
        }
    }
}

#Preview {
    InAppAutomationListDebugView()
}
