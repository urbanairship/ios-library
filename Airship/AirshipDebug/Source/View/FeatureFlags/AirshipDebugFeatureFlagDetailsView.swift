/* Copyright Airship and Contributors */

import Combine
import SwiftUI
import AirshipCore
import AirshipFeatureFlags

struct AirshipDebugFeatureFlagDetailsView: View {

    @StateObject
    private var viewModel: ViewModel

    @State
    private var toastMessage: AirshipToast.Message? = nil

    init(name: String) {
        _viewModel = .init(wrappedValue: .init(name: name))
    }

    @ViewBuilder
    var body: some View {
        Form {
            Section(header: Text("Details".localized())) {
                makeInfoItem("Name".localized(), viewModel.name)
            }

            Section(
                content: {
                    if let result = self.viewModel.result {
                        makeInfoItem("Elegible".localized(), result.isEligible ? "true" : "false")
                        makeInfoItem("Exists".localized(), result.exists ? "true" : "false")

                        if let variables = result.variables {
                            Section(header: Text("Variables: ".localized())) {
                                AirshipJSONView(json: variables)
                                    .padding(.leading, 8)
                            }
                        }

                        Button("Track Interaction") {
                            Airship.featureFlagManager.trackInteraction(flag: result)
                        }.frame(maxWidth: .infinity, alignment: .center)
                    } else {
                        VStack {
                            ProgressView()
                                .padding()
                            Text("Resolving flag")
                        }.frame(maxWidth: .infinity)
                    }
                },
                header: {
                    HStack {
                        Text("Result".localized())
                        Spacer()

                        if let result = self.viewModel.result {
                            makeShareLink(AirshipJSON.wrapSafe(result).prettyString)
                        }

                        if self.viewModel.result != nil || self.viewModel.error != nil {
                            Button {
                                self.viewModel.evaluateFlag()
                            } label: {
                                Image(systemName: "arrow.clockwise")
                            }
                        }
                    }
                }
            )
        }
        .navigationTitle(viewModel.name)
        .onAppear {
            self.viewModel.evaluateFlag()
        }
        .overlay(AirshipToast(message: self.$toastMessage))
    }

    @ViewBuilder
    func makeShareLink(_ string: String) -> some View {
#if !os(tvOS)
        ShareLink(item: string) {
            Image(systemName: "square.and.arrow.up")
        }
#else
        Button {
            copyToClipboard(value: string)
        } label: {
            Image(systemName: "doc.on.clipboard.fill")
        }
#endif
    }

    @ViewBuilder
    func makeInfoItem(_ title: String, _ value: String?) -> some View {
        HStack {
            Text(title)
                .foregroundColor(.primary)
            Spacer()
            Text(value ?? "")
                .foregroundColor(.secondary)
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

        @Published private(set) var result: FeatureFlag?
        @Published private(set) var error: String?

        let name: String

        init(name: String) {
            self.name = name
        }

        func evaluateFlag() {
            self.result = nil
            self.error = nil
            Task { @MainActor in
                do {
                    self.result = try await Airship.featureFlagManager.flag(name: name)
                } catch {
                    self.error = error.localizedDescription
                }
            }
        }
    }
}


#Preview {
    AirshipDebugFeatureFlagDetailsView(name: "some flag name")
}
