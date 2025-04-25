// Copyright Urban Airship and Contributors


import SwiftUI

struct AppInfo {
    let bundleId: String
    let timeZone: String
    let sdkVersion: String
    let appVersion: String
    let appCodeVersion: String
    let applicationLocale: String
    
    func copyWith(locale: String? = nil) -> AppInfo {
        return .init(
            bundleId: self.bundleId,
            timeZone: TimeZone.autoupdatingCurrent.identifier,
            sdkVersion: self.sdkVersion,
            appVersion: self.appVersion,
            appCodeVersion: self.appCodeVersion,
            applicationLocale: locale ?? self.applicationLocale)
    }
}

struct AppInfoDebugView: View {
    
    @Binding var info: AppInfo
    @Binding var selectedLocale: String
    
    @State
    private var toast: AirshipToast.Message? = nil
    
    let onClearLocale: () -> Void
    
    var body: some View {
        Form {
            CommonItems.infoRow(
                title: "Airship SDK Version".localized(),
                value: info.sdkVersion,
                onTap: { copyValue(info.sdkVersion) }
            )
            
            CommonItems.infoRow(
                title: "App Version".localized(),
                value: info.appVersion,
                onTap: { copyValue(info.appVersion) }
            )
            
            CommonItems.infoRow(
                title: "App Code Version".localized(),
                value: info.appCodeVersion,
                onTap: { copyValue(info.appCodeVersion) }
            )
            
            CommonItems.infoRow(
                title: "Bundle ID".localized(),
                value: info.bundleId,
                onTap: { copyValue(info.bundleId) }
            )
            
            CommonItems.infoRow(
                title: "Time Zone".localized(),
                value: info.timeZone,
                onTap: { copyValue(info.timeZone) }
            )
            
            CommonItems.infoRow(
                title: "App Locale".localized(),
                value: info.applicationLocale,
                onTap: { copyValue(info.applicationLocale) }
            )
            
            Picker(
                selection: self.$selectedLocale,
                label: Text("Locale Override".localized())
            ) {
                let allIDs = Locale.availableIdentifiers
                ForEach(allIDs, id: \.self) { localeID in  // <1>
                    Text(localeID)
                }
            }
            .foregroundColor(.primary)
            .frame(height: CommonItems.rowHeight)
            
            Button("Clear Locale Override".localized(), action: onClearLocale)
                .frame(height: CommonItems.rowHeight)
        }
        .toastable($toast)
        .navigationTitle("App Info".localized())
    }
    
    private func copyValue(_ value: String) {
        value.pastleboard()
        
        toast = .init(text: "Copied to clipboard")
    }
}

#Preview {
    AppInfoDebugView(
        info: .constant(.init(
            bundleId: "bundle id",
            timeZone: "time zone",
            sdkVersion: "sdk version",
            appVersion: "app version",
            appCodeVersion: "app code version",
            applicationLocale: "app locale")),
        selectedLocale: .constant("en_EN"),
        onClearLocale: {}
    )
}
