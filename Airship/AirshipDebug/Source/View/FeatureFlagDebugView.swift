/* Copyright Airship and Contributors */

import Combine
import SwiftUI

#if canImport(AirshipCore)
import AirshipCore
import AirshipFeatureFlags
#elseif canImport(AirshipKit)
import AirshipKit
#endif

public struct FeatureFlagDebugView: View {

    @StateObject
    private var viewModel = ViewModel()

    public init() {}

    public var body: some View {
        Form {
            Section(header: Text("")) {
                List(self.viewModel.entries, id: \.name) { entry in
                    NavigationLink(
                        destination: FeaturFlagDetailsView(entry:entry)
                    ) {
                        VStack(alignment: .leading) {
                            Text(entry.name)
                        }
                    }
                }
            }
        }
        .navigationTitle("Feature Flags".localized())
    }

    class ViewModel: ObservableObject {
        @Published private(set) var entries: [FeatureFlagEntry] = []
        private var cancellable: AnyCancellable? = nil

        init() {
            if Airship.isFlying {
                self.cancellable = AirshipDebugManager.shared
                    .featureFlagPublisher
                    .receive(on: RunLoop.main)
                    .map { result in
                        var featureFlagEntries: [FeatureFlagEntry] = []
                        let mappedByName = Dictionary(grouping: result) { element in
                            let flag = element["flag"] as? [String : AnyHashable]
                            return flag?["name"] as? String ?? "MISSING_NAME"
                        }

                        mappedByName.forEach { (key: String, value: [[String: AnyHashable]]) in
                            let flags = value.map { payload in
                                let id = payload["flag_id"] as? String ?? "MISSING_ID"
                                return FeatureFlagEntry.FlagInfo(id: id, payload: AirshipJSON.wrapSafe(payload))
                            }

                            featureFlagEntries.append(
                                FeatureFlagEntry(
                                    name: key,
                                    flags: flags
                                )
                            )
                        }

                        return featureFlagEntries
                    }

                    .sink { incoming in
                        self.entries = incoming
                    }
            }
        }
    }
}

private struct FeaturFlagDetailsView: View {
    let entry: FeatureFlagEntry

    @StateObject
    private var viewModel = ViewModel()

    @State
    private var toastMessage: AirshipToast.Message? = nil

    @ViewBuilder
    var body: some View {
        Form {

            Section(header: Text("Details".localized())) {
                makeInfoItem("Name".localized(), entry.name)
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
                        Button("Track Interacted") {
                            FeatureFlagManager.shared.trackInteracted(flag: result)
                        }
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
                                self.viewModel.evaluateFlag(name: entry.name)
                            } label: {
                                Image(systemName: "arrow.clockwise")
                            }
                        }
                    }
                }
            )

            List(self.entry.flags, id: \.id) { entry in
                Section(
                    content:  {
                        AirshipJSONView(json: entry.payload)
                    },
                    header: {
                        HStack {
                            Text(entry.id)
                            Spacer()
                            makeShareLink(entry.payload.prettyString)
                        }
                    }
                )
            }

        }
        .navigationTitle(entry.name)
        .onAppear {
            self.viewModel.evaluateFlag(name: entry.name)
        }
        .overlay(AirshipToast(message: self.$toastMessage))
    }

    @ViewBuilder
    func makeShareLink(_ string: String) -> some View {
        if #available(iOS 16.0, *) {
            ShareLink(item: string) {
                Image(systemName: "square.and.arrow.up")
            }
        } else {
            Button {
                copyToClipboard(value: string)
            } label: {
                Image(systemName: "doc.on.clipboard.fill")
            }
        }
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

        UIPasteboard.general.string = value
        self.toastMessage = AirshipToast.Message(
            id: UUID().uuidString,
            text: "Copied to pasteboard!".localized(),
            duration: 1.0
        )
    }

    class ViewModel: ObservableObject {

        @Published private(set) var result: FeatureFlag?
        @Published private(set) var error: String?

        init() {
        }

        func evaluateFlag(name: String) {
            self.result = nil
            self.error = nil
            Task { @MainActor in
                do {
                    self.result = try await FeatureFlagManager.shared.flag(name: name)
                } catch {
                    self.error = error.localizedDescription
                }
            }
        }
    }
}

struct FeatureFlagEntry {
    // Name
    let name: String

    // Flags
    let flags: [FlagInfo]

    struct FlagInfo {
        // Flag ID
        let id: String

        // Flag JSON payload
        let payload: AirshipJSON
    }

}
