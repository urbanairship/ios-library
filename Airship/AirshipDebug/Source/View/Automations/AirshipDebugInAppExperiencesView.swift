// Copyright Airship and Contributors

import SwiftUI
import Combine
import AirshipCore
import AirshipAutomation

struct AirshipDebugInAppExperiencesView: View {

    @StateObject
    private var viewModel: ViewModel = .init()

    var body: some View {
        Form {
            CommonItems.navigationLink(
                title: "Automations".localized(),
                route: .inAppExperienceSub(.automations)
            )
            
            CommonItems.navigationLink(
                title: "Experiments".localized(),
                route: .inAppExperienceSub(.experiments)
            )
            
            displayIntervalRow()
        }
        .navigationTitle("In-App Experiences".localized())
    }
    
    private var displayIntervalString: String {
        viewModel.displayInterval.formatted(.number.precision(.fractionLength(1)))
    }
    
    @ViewBuilder
    private func displayIntervalRow() -> some View {
        VStack {
            HStack {
                Text("Display Interval".localized())
                    .foregroundColor(.primary)
                Spacer()
                Text("\(displayIntervalString) seconds")
                    .foregroundColor(.secondary)
            }
#if os(tvOS)
            TVSlider(
                displayInterval: self.$viewModel.displayInterval,
                range: 0.0...200.0,
                step: 1.0
            )
#else
            Slider(
                value: self.$viewModel.displayInterval,
                in: 0.0...200.0,
                step: 1.0
            )
#endif
        }
    }

    @MainActor
    fileprivate final class ViewModel: ObservableObject {
        @Published
        var displayInterval: TimeInterval = 0.0 {
            didSet {
                guard Airship.isFlying else { return }
                Airship.inAppAutomation.inAppMessaging.displayInterval = self.displayInterval
            }
        }
        
        @MainActor
        init() {
            Airship.onReady { [weak self] in
                self?.displayInterval = Airship.inAppAutomation.inAppMessaging.displayInterval
            }
        }
    }
}

#Preview {
    AirshipDebugInAppExperiencesView()
}
