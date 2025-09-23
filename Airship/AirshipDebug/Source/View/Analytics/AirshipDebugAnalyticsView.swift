// Copyright Airship and Contributors

import SwiftUI

struct AirshipDebugAnalyticsView: View {

    var body: some View {
        Form {
            CommonItems.navigationLink(
                title: "Events".localized(),
                route: .analyticsSub(.events)
            )
            CommonItems.navigationLink(
                title: "Add Custom Event".localized(),
                route: .analyticsSub(.addEvent)
            )
            CommonItems.navigationLink(
                title: "Associated Identifiers".localized(),
                route: .analyticsSub(.associatedIdentifiers)
            )
        }
        .navigationTitle("Analytics".localized())
    }
}

#Preview {
    AirshipDebugAnalyticsView()
}

