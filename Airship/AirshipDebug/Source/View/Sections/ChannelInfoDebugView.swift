/* Copyright Urban Airship and Contributors */

import SwiftUI
#if canImport(AirshipCore)
import AirshipCore
#elseif canImport(AirshipKit)
import AirshipKit
#endif

struct ChannelInfoDebugView: View {
    
    let channelId: () -> String?
    
    @State
    private var toastMessage: AirshipToast.Message? = nil
    
    var body: some View {
        Form {
            CommonItems.infoRow(
                title: "Channel ID".localized(),
                value: channelId(),
                onTap: { copyChananelId(channelId())}
            )
            
            CommonItems.navigationRow(
                title: "Tags".localized(),
                destination: DeviceTagsDebugView())
            
            CommonItems.navigationRow(
                title: "Tag Groups".localized(),
                destination: TagGroupsDebugView {
                    guard Airship.isFlying else { return nil }
                    return Airship.channel.editTagGroups()
                }
            )
            
            CommonItems.navigationRow(
                title: "Attributes".localized(),
                destination: AttributesDebugView {
                    guard Airship.isFlying else { return nil }
                    return Airship.channel.editAttributes()
                }
            )
            
            CommonItems.navigationRow(
                title: "Subscription Lists".localized(),
                destination: SubscriptionListsDebugView {
                    guard Airship.isFlying else { return nil }
                    return Airship.channel.editSubscriptionLists()
                }
            )
            
        }
        .toastable($toastMessage)
        .navigationTitle("Channel".localized())
    }
    
    private func copyChananelId(_ channelId: String?) {
        guard let channelId else { return }
        
        channelId.pastleboard()
        self.toastMessage = .init(text: "Channel ID copied to clipboard")
    }
}

#Preview {
    ChannelInfoDebugView(channelId: { "test channel id"})
}
