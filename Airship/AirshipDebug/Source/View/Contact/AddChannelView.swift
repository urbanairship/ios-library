/* Copyright Airship and Contributors */

import SwiftUI

struct AddChannelView: View {
    var body: some View {
        Form {
            Section(header: Text("Channel Type".localized())) {
                NavigationLink(
                    "Open Channel".localized(),
                    destination: CreateOpenChannelView()
                )

                NavigationLink(
                    "SMS Channel".localized(),
                    destination: CreateSMSChannelView()
                )

                NavigationLink(
                    "Email Channel".localized(),
                    destination: CreateEmailChannelView()
                )
            }
        }
        .navigationTitle("Add Channel".localized())

    }
}
