/* Copyright Airship and Contributors */

import Foundation
import SwiftUI

/// Button view.
@available(iOS 13.0.0, tvOS 13.0, *)
struct AirshipButton : View {
    
    /// Button model.
    let model: ButtonModel
    
    /// View constriants.
    let constraints: ViewConstraints
    
    var body: some View {
        Button(action: {
            print("Button action")
        }) {
            Label(model: self.model.label, constraints: constraints)
                .padding()
                .frame(idealWidth: constraints.width ?? 0,
                       maxWidth: constraints.width,
                       idealHeight: constraints.height ?? 0,
                       maxHeight: constraints.height)
                .background(self.model.background)
                .border(self.model.border)

        }.constraints(constraints)
    }
}
