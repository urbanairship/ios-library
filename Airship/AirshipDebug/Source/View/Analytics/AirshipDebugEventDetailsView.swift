/* Copyright Airship and Contributors */

import Combine
import SwiftUI
import AirshipCore

struct AirshipDebugEventDetailsView: View {

    @State
    private var toastMessage: AirshipToast.Message? = nil

    @StateObject
    private var viewModel: ViewModel

    public init(identifier: String) {
        _viewModel = .init(wrappedValue: .init(identifier: identifier))
    }

    @ViewBuilder
    var body: some View {
        Form {
            if let event = self.viewModel.event {
                Section(header: Text("Event Details".localized())) {
                    makeInfoItem("Type", event.type)
                    makeInfoItem("ID", event.identifier)
                    makeInfoItem(
                        "Date",
                        AirshipDateFormatter.string(fromDate: event.date, format: .iso)
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
            } else {
                ProgressView()
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

    @MainActor
    class ViewModel: ObservableObject {
        @Published private(set) var event: AirshipEvent?

        init(identifier: String) {
            Task { @MainActor [weak self] in
                self?.event = await Airship.internalDebugManager.events().first(
                    where: { event in
                        event.identifier == identifier
                    }
                )
            }
        }
    }
}
