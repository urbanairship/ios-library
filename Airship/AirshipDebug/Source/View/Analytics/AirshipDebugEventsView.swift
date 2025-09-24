/* Copyright Airship and Contributors */

import Combine
import SwiftUI
import AirshipCore

struct AirshipDebugEventsView: View {
    
    @StateObject
    private var viewModel = ViewModel()
    
    var body: some View {
        Form {
            Section {
                ForEach(self.viewModel.events, id: \.identifier) { event in
                    
                    NavigationLink(
                        value: AirshipDebugRoute.analyticsSub(.eventDetails(identifier: event.identifier))
                    ) {
                        VStack(alignment: .leading) {
                            Text(event.type)
                            Text(event.identifier)
                            HStack {
                                Text(event.date, style: .date)
                                Text(event.date, style: .time)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Events".localized())
    }
    
    @MainActor
    class ViewModel: ObservableObject {
        @Published private(set) var events: [AirshipEvent] = []
        
        @Published
        var searchString: String = "" {
            didSet {
                refreshEvents()
            }
        }
        
        private var cancellable: AnyCancellable? = nil
        
        init() {
            if Airship.isFlying {
                self.cancellable = Airship.internalDebugManager
                    .eventReceivedPublisher
                    .sink { [weak self] incoming in
                        self?.refreshEvents()
                    }
            }
            
            refreshEvents()
        }
        
        private func refreshEvents() {
            if !Airship.isFlying { return }
            
            Task { @MainActor in
                let events = await Airship.internalDebugManager.events(
                    searchString: self.searchString
                )
                self.events = events
            }
        }
    }
}

#Preview {
    AirshipDebugEventsView()
}
