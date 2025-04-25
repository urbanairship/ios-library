// Copyright Urban Airship and Contributors


import SwiftUI
#if canImport(AirshipCore)
import AirshipCore
#elseif canImport(AirshipKit)
import AirshipKit
#endif

struct ContactsDebugView: View {
    
    @Binding
    var namedUserId: String?
    
    @ViewBuilder
    var body: some View {
        Form {
            CommonItems.navigationRow(
                title: "Named User".localized(),
                trailingView: {
                    HStack {
                        if let namedUserId {
                            Text(namedUserId)
                                .foregroundColor(.secondary)
                        }
                    }
                },
                destination: NamedUserDebugView())
            
            CommonItems.navigationRow(
                title: "Tag Groups".localized(),
                destination: TagGroupsDebugView {
                    guard Airship.isFlying else { return nil }
                    return Airship.contact.editTagGroups()
                })
            
            CommonItems.navigationRow(
                title: "Attributes".localized(),
                destination: AttributesDebugView {
                    guard Airship.isFlying else { return nil }
                    return Airship.contact.editAttributes()
                })
            
            CommonItems.navigationRow(
                title: "Subscription Lists".localized(),
                destination: ScopedSubscriptionListsDebugView {
                    guard Airship.isFlying else { return nil }
                    return Airship.contact.editSubscriptionLists()
                })
            
            CommonItems.navigationRow(
                title: "Add Channel".localized(),
                destination: AddChannelView())
        }
        .navigationTitle("Contact".localized())
    }
}

#Preview {
    ContactsDebugView(
        namedUserId: .constant("test username")
    )
}
