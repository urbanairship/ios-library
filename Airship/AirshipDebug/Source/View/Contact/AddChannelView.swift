/* Copyright Airship and Contributors */

import SwiftUI

public struct AddChannelView: View {
    public init() {}

    public var body: some View {
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
