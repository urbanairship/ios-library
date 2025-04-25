// Copyright Urban Airship and Contributors


import SwiftUI

struct DeviceInfoDebugView: View {
    
    @Binding var appInfo: AppInfo
    
    @Binding var channelId: String?
    
    @Binding
    var isUserPushEnabled: Bool
    
    @Binding
    var isBackgroundPushEnabled: Bool
    
    
    @Binding
    var deviceToken: String?
    
    @State
    private var toast: AirshipToast.Message? = nil
    
    private var optInStatus: String {
        return isUserPushEnabled ? "Opted-In" : "Opted-Out"
    }
    
    @ViewBuilder
    var body: some View {
        Form {
            
            Section("Info".localized().uppercased()) {
                CommonItems.infoRow(
                    title: "Channel ID".localized(),
                    value: channelId,
                    onTap: { copyToClipboard(channelId) }
                )
                
                CommonItems.infoRow(
                    title: "Airship SDK Version".localized(),
                    value: appInfo.sdkVersion,
                    onTap: { copyToClipboard(appInfo.sdkVersion) }
                )
                
                CommonItems.infoRow(
                    title: "Current Locale".localized(),
                    value: appInfo.applicationLocale,
                    onTap: { copyToClipboard(appInfo.applicationLocale) }
                )
                
                CommonItems.infoRow(
                    title: "Model".localized(),
                    value: UIDevice.current.model,
                    onTap: { copyToClipboard(UIDevice.current.model) }
                )
            }
            
            Section(header: Text("Push".localized())) {
                Toggle(
                    "Notification Enabled".localized(),
                    isOn: self.$isUserPushEnabled
                )
                .frame(height: 34)
                
                Toggle(
                    "Background Push Enabled".localized(),
                    isOn: self.$isBackgroundPushEnabled
                )
                .frame(height: 34)
                
                CommonItems.infoRow(
                    title: "Opt-In Status".localized(),
                    value: optInStatus.localized()
                )
                
                CommonItems.infoRow(
                    title: "Device Token".localized(),
                    value: deviceToken,
                    onTap: { copyToClipboard(deviceToken) }
                )
                
                CommonItems.navigationRow(
                    title: "Received Pushes".localized(),
                    trailingView: { EmptyView() },
                    destination: ReceivedPushListDebugView())
            }
        }
        .toastable($toast)
        .navigationTitle("Device Info".localized())
    }
    
    private func copyToClipboard(_ value: String?) {
        guard let value else { return }
        value.pastleboard()
        
        self.toast = .init(text: "Copied to clipboard".localized())
    }
    
}

#Preview {
    DeviceInfoDebugView(
        appInfo: .constant(.init(
            bundleId: "bundle id",
            timeZone: "time zone",
            sdkVersion: "sdk version",
            appVersion: "app version",
            appCodeVersion: "app code version",
            applicationLocale: "app locale")),
        channelId: .constant("channel id"),
        isUserPushEnabled: .constant(true),
        isBackgroundPushEnabled: .constant(false),
        deviceToken: .constant("APNS token")
    )
}
