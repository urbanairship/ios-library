// Copyright Airship and Contributors

import SwiftUI
import Combine
import AirshipCore

fileprivate struct AppInfo: Sendable {
    let bundleId: String
    let timeZone: String
    let sdkVersion: String
    let appVersion: String
    let appCodeVersion: String
    let applicationLocale: String
}

struct AirshipDebugAppInfoView: View {

    @StateObject
    private var viewModel = ViewModel()

    @State
    private var toast: AirshipToast.Message? = nil


    var body: some View {
        Form {
            CommonItems.infoRow(
                title: "Airship SDK Version".localized(),
                value: viewModel.appInfo.sdkVersion,
                onTap: { copyValue(viewModel.appInfo.sdkVersion) }
            )

            CommonItems.infoRow(
                title: "App Version".localized(),
                value: viewModel.appInfo.appVersion,
                onTap: { copyValue(viewModel.appInfo.appVersion) }
            )

            CommonItems.infoRow(
                title: "App Code Version".localized(),
                value: viewModel.appInfo.appCodeVersion,
                onTap: { copyValue(viewModel.appInfo.appCodeVersion) }
            )

            CommonItems.infoRow(
                title: "Model".localized(),
                value: UIDevice.current.model,
                onTap: { copyValue(UIDevice.current.model) }
            )

            CommonItems.infoRow(
                title: "Bundle ID".localized(),
                value: viewModel.appInfo.bundleId,
                onTap: { copyValue(viewModel.appInfo.bundleId) }
            )

            CommonItems.infoRow(
                title: "Time Zone".localized(),
                value: viewModel.appInfo.timeZone,
                onTap: { copyValue(viewModel.appInfo.timeZone) }
            )

            CommonItems.infoRow(
                title: "App Locale".localized(),
                value: viewModel.appInfo.applicationLocale,
                onTap: { copyValue(viewModel.appInfo.applicationLocale) }
            )

            Picker(
                selection: self.$viewModel.airshipLocaleIdentifier,
                label: Text("Airship Locale".localized())
            ) {
                let allIDs = Locale.availableIdentifiers
                ForEach(allIDs, id: \.self) { localeID in  // <1>
                    Text(localeID)
                }
            }
            .foregroundColor(.primary)
            .frame(height: CommonItems.rowHeight)

            Button(
                "Clear Locale Override".localized(),
                role: .destructive
            ) { [weak viewModel] in
                viewModel?.clearLocaleOverride()
            }
            .frame(height: CommonItems.rowHeight)
        }
        .toastable($toast)
        .navigationTitle("App Info".localized())
    }

    private func copyValue(_ value: String) {
        value.pastleboard()
        toast = .init(text: "Copied to clipboard")
    }
    
    @MainActor
    fileprivate final class ViewModel: ObservableObject {
        @Published
        var appInfo: AppInfo

        @Published
        var airshipLocaleIdentifier: String {
            didSet {
                guard Airship.isFlying else { return }

                Airship.localeManager.currentLocale = Locale(
                    identifier: airshipLocaleIdentifier
                )
            }
        }

        @MainActor
        init() {
            self.appInfo = .init(
                bundleId: Bundle.main.bundleIdentifier ?? "",
                timeZone: TimeZone.autoupdatingCurrent.identifier,
                sdkVersion: AirshipVersion.version,
                appVersion: (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String)
                ?? "",
                appCodeVersion: (Bundle.main.infoDictionary?["CFBundleVersion"] as? String) ?? "",
                applicationLocale: Locale.autoupdatingCurrent.identifier
            )

            self.airshipLocaleIdentifier = ""
            Airship.onReady { [weak self] in
                self?.airshipLocaleIdentifier = Airship.localeManager.currentLocale.identifier
            }
        }

        func clearLocaleOverride() {
            if Airship.isFlying {
                self.airshipLocaleIdentifier = Locale.autoupdatingCurrent.identifier
                Airship.localeManager.clearLocale()
            }
        }
    }
}

#Preview {
    AirshipDebugAppInfoView()
}
