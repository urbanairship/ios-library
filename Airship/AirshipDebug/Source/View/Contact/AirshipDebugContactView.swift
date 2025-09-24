// Copyright Airship and Contributors

import Combine
import SwiftUI
import AirshipCore

struct AirshipDebugContactsView: View {

    @StateObject
    private var viewModel = ViewModel()

    @ViewBuilder
    var body: some View {
        Form {
            Section {
                CommonItems.navigationLink(
                    title: "Named User".localized(),
                    trailingView: {
                        HStack {
                            if let namedUserID = viewModel.namedUserID {
                                Text(namedUserID)
                                    .foregroundColor(.secondary)
                            }
                        }
                    },
                    route: .contactSub(.namedUserID)
                )

                CommonItems.navigationLink(
                    title: "Tag Groups".localized(),
                    route: .contactSub(.tagGroups)
                )

                CommonItems.navigationLink(
                    title: "Attributes".localized(),
                    route: .contactSub(.attributes)
                )

                CommonItems.navigationLink(
                    title: "Subscription Lists".localized(),
                    route: .contactSub(.subscriptionLists)
                )
            }

            Section("Channels".localized()) {
                CommonItems.navigationLink(
                    title: "Add Email Channel".localized(),
                    route: .contactSub(.addEmailChannel)
                )
                CommonItems.navigationLink(
                    title: "Add SMS Channel".localized(),
                    route: .contactSub(.addSMSChannel)
                )
                CommonItems.navigationLink(
                    title: "Add Open Channel".localized(),
                    route: .contactSub(.addOpenChannel)
                )
            }
        }
        .navigationTitle("Contact".localized())
    }


    @MainActor
    fileprivate final class ViewModel: ObservableObject {
        @Published
        var namedUserID: String?

        private var task: Task<Void, Never>? = nil
        private var subscription: AnyCancellable? = nil

        @MainActor
        init() {
            self.task = Task { [weak self] in
                await Airship.waitForReady()
                self?.update(
                    namedUserID: await Airship.contact.namedUserID
                )

                for await namedUserID in Airship.contact.namedUserIDPublisher.values {
                    self?.update(namedUserID: namedUserID)
                }
            }
        }

        deinit {
            task?.cancel()
        }

        private func update(namedUserID: String?) {
            if self.namedUserID != namedUserID {
                self.namedUserID = namedUserID
            }
        }
    }
}

#Preview {
    AirshipDebugContactsView()
}
