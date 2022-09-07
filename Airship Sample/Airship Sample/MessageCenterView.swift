/* Copyright Urban Airship and Contributors */

import Foundation
import UIKit
import AirshipMessageCenter
import SwiftUI
import Combine
import AirshipCore

struct MessageCenterView: View {

    @EnvironmentObject
    private var appState: AppState

    var body: some View {
        NavigationView {
            MessageCenterListView(messageID: self.$appState.messageID)
            Text("Select a message")
        }
    }
}
