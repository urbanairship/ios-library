/* Copyright Airship and Contributors */

import Foundation
import SwiftUI
import Combine

/// Image Button view.
@available(iOS 13.0.0, tvOS 13.0, *)
struct ImageButton : View {
 
    /// Image Button model.
    let model: ImageButtonModel
  
    /// View constriants.
    let constraints: ViewConstraints
  
    @Environment(\.colorScheme) var colorScheme

    @ViewBuilder
    var body: some View {
        Button(action: {}) {
            createInnerButton()
                .padding(4)
                .constraints(constraints)
                .background(self.model.backgroundColor)
                .border(self.model.border)
                .viewAccessibility(label: self.model.contentDescription)

        }
        .buttonClick(self.model.identifier,
                     buttonDescription: self.model.contentDescription,
                     behaviors: self.model.clickBehaviors,
                     actions: self.model.actions)
        .enableButton(self.model.enableBehaviors)
    }
    
    @ViewBuilder
    private func createInnerButton() -> some View {
        switch(model.image) {
        case .url(let model):
            AirshipAsyncImage(url: model.url) { image in
                image
                    .renderingMode(.original)
                    .resizable()
                    .scaledToFit()
            } placeholder: {
                AirshipProgressView()
            }
        case .icon(let model):
            Icons.icon(model: model, colorScheme: colorScheme)
        }
    }
}
