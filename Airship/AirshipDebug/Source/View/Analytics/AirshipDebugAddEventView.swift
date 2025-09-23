import AirshipCore
import Foundation
import SwiftUI
import Combine

struct AirshipDebugAddEventView: View {

    @StateObject
    private var viewModel = ViewModel()

    @Environment(\.presentationMode)
    private var presentationMode: Binding<PresentationMode>

    @State var shouldPresentPropetySheet = false

    public init() {}

    @ViewBuilder
    func makeTextInput(title: String, binding: Binding<String>) -> some View {
        HStack {
            Text(title.lowercased())
            Spacer()
            TextField(title.lowercased(), text: binding.preventWhiteSpace())
                .freeInput()
        }
    }

    @ViewBuilder
    func makeNumberInput(title: String, binding: Binding<Double>) -> some View {
        HStack {
            Text(title.lowercased())
            Spacer()
            TextField(
                title.lowercased(),
                value: binding,
                formatter: NumberFormatter()
            )
            .keyboardType(.numberPad)
        }
    }

    var body: some View {
        Form {
            Section(header: Text("Event Properties".localized())) {
                makeTextInput(
                    title: "Event Name",
                    binding: self.$viewModel.eventName
                )
                makeNumberInput(
                    title: "Event Value",
                    binding: self.$viewModel.eventValue
                )
                makeTextInput(
                    title: "Transaction ID",
                    binding: self.$viewModel.transactionID
                )
                makeTextInput(
                    title: "Interaction ID",
                    binding: self.$viewModel.interactionID
                )
                makeTextInput(
                    title: "Interaction Type",
                    binding: self.$viewModel.interactionType
                )
            }

            Section(header: Text("Properties".localized())) {
                Button("Add Property".localized()) {
                    self.shouldPresentPropetySheet = true
                }
                .sheet(isPresented: self.$shouldPresentPropetySheet) {
                    NavigationStack {
                        AirshipDebugAddPropertyView {
                            self.viewModel.properties[$0] = $1
                        }
                        .navigationTitle("New Property")
#if !os(tvOS)
                        .navigationBarTitleDisplayMode(.inline)
#endif
                    }
                    .presentationDetents([.medium])
                }
                List {
                    let keys = [String](self.viewModel.properties.keys)
                    ForEach(keys, id: \.self) { key in
                        HStack {
                            Text("\(key):")
                            Text(
                                self.viewModel.properties[key]?.prettyString ?? "-"
                            )
                        }
                    }
                    .onDelete {
                        $0.forEach { index in
                            self.viewModel.properties[keys[index]] = nil
                        }
                    }
                }
            }

        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    self.viewModel.createEvent()
                    presentationMode.wrappedValue.dismiss()
                } label: {
                    Text("Create".localized())
                }
                .disabled(self.viewModel.eventName.isEmpty)
            }
        }
        .navigationTitle("Custom Event".localized())
    }

    @MainActor
    fileprivate class ViewModel: ObservableObject {
        @Published var eventName: String = ""
        @Published var eventValue: Double = 1.0
        @Published var interactionID: String = ""
        @Published var interactionType: String = ""
        @Published var transactionID: String = ""

        var properties: [String: AirshipJSON] = [:]

        func createEvent() {
            guard
                Airship.isFlying,
                !self.eventName.isEmpty
            else {
                return
            }

            var event = CustomEvent(
                name: self.eventName,
                value: self.eventValue
            )
            if !self.transactionID.isEmpty {
                event.transactionID = self.transactionID
            }
            if !self.interactionID.isEmpty && !self.interactionType.isEmpty {
                event.interactionID = self.interactionID
                event.interactionType = self.interactionType
            }
            try? event.setProperties(self.properties)

            event.track()
        }
    }
}

#Preview {
    AirshipDebugAddEventView()
}
