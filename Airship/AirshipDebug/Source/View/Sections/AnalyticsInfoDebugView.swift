// Copyright Urban Airship and Contributors


import SwiftUI

struct AnalyticsDebugView: View {
    
    var body: some View {
        Form {
            CommonItems.navigationRow(
                title: "Events".localized(),
                destination: EventListDebugView())
            
            CommonItems.navigationRow(
                title: "Add Custom Event".localized(),
                destination: AddCustomEventView())
            
            CommonItems.navigationRow(
                title: "Associated Identifiers".localized(),
                destination: AnalyticsIdentifiersView())
        }
        .navigationTitle("Analytics".localized())
    }
}

#Preview {
    AnalyticsDebugView()
}

