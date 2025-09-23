/* Copyright Airship and Contributors */

import SwiftUI
import Combine

#if canImport(AirshipCore)
import AirshipCore
#elseif canImport(AirshipKit)
import AirshipKit
#endif

struct AirshipDebugAddEmailChannelView: View {

    enum RegistrationType: String, Equatable, CaseIterable {
        case transactional = "Transactional"
        case commercial = "Commercial"
    }

    public init() {}
    
    @StateObject
    private var viewModel = ViewModel()

    @Environment(\.presentationMode)
    private var presentationMode: Binding<PresentationMode>

    @State
    private var shouldPresentPropetySheet: Bool = false
    
    var body: some View {
        Form {
            Section(header: Text("Channel Info".localized())) {
                HStack {
                    Text("Email")
                    Spacer()
                    TextField(
                        "Email",
                        text: self.$viewModel.emailAddress.preventWhiteSpace()
                    )
                    .freeInput()
                }

                Picker(
                    "Registration Type".localized(),
                    selection: self.$viewModel.registrationType
                ) {
                    ForEach(RegistrationType.allCases, id: \.self) { value in
                        Text(value.rawValue.localized())
                    }
                }
                .pickerStyle(.segmented)
            }

            if self.viewModel.registrationType == .commercial {
                Section(header: Text("Commercial Options".localized())) {
                    Toggle("Double Opt-In", isOn: self.$viewModel.doubleOptIn)
                }
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
                                self.viewModel.properties[key]?.prettyString
                                    ?? ""
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
                    self.viewModel.createChannel()
                    presentationMode.wrappedValue.dismiss()
                } label: {
                    Text("Create".localized())
                }
                .disabled(self.viewModel.emailAddress.isEmpty)
            }
        }
        .navigationTitle("Email Channel".localized())
    }

    @MainActor
    fileprivate class ViewModel: ObservableObject {
        @Published var emailAddress: String = ""
        @Published var commercial: Bool = false
        @Published var registrationType: RegistrationType = .transactional
        @Published var doubleOptIn: Bool = false
        @Published var properties: [String: AirshipJSON] = [:]

        func createChannel() {
            guard
                Airship.isFlying,
                !self.emailAddress.isEmpty
            else {
                return
            }

            var options: EmailRegistrationOptions!
            let date = Date()

            switch self.registrationType {
            case .commercial:
                if doubleOptIn {
                    options = EmailRegistrationOptions.options(
                        transactionalOptedIn: date,
                        properties: properties,
                        doubleOptIn: true
                    )
                } else {
                    options = EmailRegistrationOptions.commercialOptions(
                        transactionalOptedIn: date,
                        commercialOptedIn: date,
                        properties: properties,
                    )
                }
            case .transactional:
                options = EmailRegistrationOptions.options(
                    transactionalOptedIn: date,
                    properties: properties,
                    doubleOptIn: false
                )
            }

            Airship.contact.registerEmail(
                self.emailAddress,
                options: options
            )
        }
    }
}

#Preview {
    AirshipDebugAddEmailChannelView()
}
