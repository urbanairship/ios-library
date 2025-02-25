/* Copyright Airship and Contributors */

import Combine
public import SwiftUI

#if canImport(AirshipCore)
import AirshipCore
#elseif canImport(AirshipKit)
import AirshipKit
#endif

public struct EventListDebugView: View {

    @StateObject
    private var viewModel = ViewModel()

    @ViewBuilder
    public func makeList() -> some View {
        List(self.viewModel.events, id: \.identifier) { event in
            NavigationLink(
                destination: EventDetailsView(event: event)
            ) {
                VStack(alignment: .leading) {
                    Text(event.type)
                    Text(event.identifier)
                    HStack {
                        Text(event.date, style: .date)
                        Text(event.date, style: .time)
                    }
                }
            }
        }
    }

    public init() {}
    
    public var body: some View {
        Form {
            Section(header: Text("Events")) {
                makeList()
            }
        }
        .navigationTitle("Events".localized())
    }

    @MainActor
    class ViewModel: ObservableObject {
        @Published private(set) var events: [AirshipEvent] = []

        @Published
        var searchString: String = "" {
            didSet {
                refreshEvents()
            }
        }

        private var cancellable: AnyCancellable? = nil

        init() {
            if Airship.isFlying {
                self.cancellable = Airship.debugManager
                    .eventReceivedPublisher
                    .sink { [weak self] incoming in
                        self?.refreshEvents()
                    }
            }

            refreshEvents()
        }

        private func refreshEvents() {
            Task { @MainActor in
                let events = await Airship.debugManager.events(
                    searchString: self.searchString
                )
                self.events = events
            }
        }
    }
}

private struct EventDetailsView: View {
    let event: AirshipEvent

    @State
    private var toastMessage: AirshipToast.Message? = nil

    @ViewBuilder
    var body: some View {
        Form {
            Section(header: Text("Event Details".localized())) {
                makeInfoItem("Type", self.event.type)
                makeInfoItem("ID", self.event.identifier)
                makeInfoItem(
                    "Date",
                    AirshipDateFormatter.string(fromDate: self.event.date, format: .iso)
                )
            }

            Section(header: Text("Event body".localized())) {
                Button(action: {
                    copyToClipboard(value: event.body)
                }) {
                    Text(event.body)
                        .foregroundColor(.primary)
                }
            }
        }
        .overlay(AirshipToast(message: self.$toastMessage))
        .navigationTitle("Event".localized())
    }

    @ViewBuilder
    func makeInfoItem(_ title: String, _ value: String?) -> some View {
        Button(action: {
            if let value = value {
                copyToClipboard(value: value)
            }
        }) {
            HStack {
                Text(title)
                    .foregroundColor(.primary)
                Spacer()
                Text(value ?? "")
                    .foregroundColor(.secondary)
            }
        }
    }

    func copyToClipboard(value: String?) {
        guard let value = value else {
            return
        }
        value.pastleboard()
        self.toastMessage = AirshipToast.Message(
            id: UUID().uuidString,
            text: "Copied to pasteboard!".localized(),
            duration: 1.0
        )
    }
}
