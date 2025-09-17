/* Copyright Airship and Contributors */

import Combine
public import SwiftUI

#if canImport(AirshipCore)
import AirshipCore
import AirshipPreferenceCenter
#elseif canImport(AirshipKit)
import AirshipKit
#endif

public struct PreferenceCenterListDebugView: View {

    @StateObject
    private var viewModel = ViewModel()

    public init() {}
    
    public var body: some View {
        Form {
            List {
                ForEach(self.viewModel.identifiers, id: \.self) {
                    identifier in
                    NavigationLink(
                        identifier,
                        destination: PreferenceCenterContent(
                            preferenceCenterID: identifier
                        )
                    )
                }
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
                self.cancellable = Airship.debugManager
                    .preferenceFormsPublisher
                    .receive(on: RunLoop.main)
                    .sink { incoming in
                        self.identifiers = incoming
                    }
            }
        }
    }
}

#Preview {
    PreferenceCenterListDebugView()
}
