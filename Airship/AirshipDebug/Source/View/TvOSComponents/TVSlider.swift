/* Copyright Airship and Contributors */

import SwiftUI

struct TVSlider: View {
    @Binding var displayInterval: Double
    var range: ClosedRange<Double>
    var step: Double = 1.0
    static private let height = 50.0
    static private let width = 500.0
    
    var body: some View {
        HStack {
            Button("-") {
                guard self.$displayInterval.wrappedValue - step >= range.upperBound else { return }
                self.$displayInterval.wrappedValue -= step
            }
            
            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(Color.accentColor.opacity(0.5))
                    .frame(width: TVSlider.width, height: TVSlider.height)
                Rectangle()
                    .fill(Color.accentColor)
                    .frame(width: TVSlider.width, height: TVSlider.height)
                
                HStack {
                    Spacer()
                    Text("\(Int($displayInterval.wrappedValue)) / \(Int(range.upperBound))")
                        .padding()
                }
                .foregroundStyle(.white)
            }
            .frame(width: TVSlider.width, height: TVSlider.height)
            .clipShape(
                RoundedRectangle(cornerRadius: 10)
                    .size(CGSize(width: TVSlider.width, height: TVSlider.height))
            )
            
            Button("+") {
                guard self.$displayInterval.wrappedValue + step <= range.upperBound else { return }
                self.$displayInterval.wrappedValue += step
            }
            
        }
        .padding()
    }
}

@available(iOS 17.0, *)
#Preview {
    
    @Previewable @State var interval: Double = 50.0
    
    TVSlider(
        displayInterval: $interval,
        range: 0.0...200.0,
        step: 1.0
    )
}
