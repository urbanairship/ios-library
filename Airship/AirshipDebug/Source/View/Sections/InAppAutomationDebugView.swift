// Copyright Urban Airship and Contributors


import SwiftUI

struct InAppAutomationDebugView: View {
    
    @Binding
    var displayInterval: TimeInterval
    
    @State
    private var toast: AirshipToast.Message? = nil
    
    var body: some View {
        Form {
            
            CommonItems.navigationRow(
                title: "Automations".localized(),
                destination: InAppAutomationListDebugView()
            )
            
            CommonItems.navigationRow(
                title: "Experiments".localized(),
                destination: ExperimentsListsDebugView()
            )
            
            displayIntervalRow()
        }
        .toastable($toast)
        .navigationTitle("In-App Automation".localized())
    }
    
    private var displayIntervalString: String {
        displayInterval.formatted(.number.precision(.fractionLength(1)))
    }
    
    
    @ViewBuilder
    private func displayIntervalRow() -> some View {
        VStack {
            Button(action: {
                self.copyDisplayInterval(self.displayInterval)
            }) {
                HStack {
                    Text("Display Interval".localized())
                        .foregroundColor(.primary)
                    Spacer()
                    Text("\(displayIntervalString) seconds")
                        .foregroundColor(.secondary)
                }
            }
#if os(tvOS)
            TVSlider(
                displayInterval: self.$displayInterval,
                range: 0.0...200.0,
                step: 1.0
            )
#else
            Slider(
                value: self.$displayInterval,
                in: 0.0...200.0,
                step: 1.0
            )
#endif
        }
        
    }
    
    private func copyDisplayInterval(_ value: TimeInterval) {
        "\(value)".pastleboard()
        self.toast = .init(text: "Display interval copied to clipboard")
    }
}

#Preview {
    InAppAutomationDebugView(
        displayInterval: .constant(4.0)
    )
}
