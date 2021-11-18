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
  
    @ObservedObject var imageLoader: AssetLoader = AssetLoader()
    @State var image: UIImage = UIImage()
    @State var imageLoaderCancellable: AnyCancellable?
    @Environment(\.colorScheme) var colorScheme

    @ViewBuilder
    var body: some View {
        Button(action: {}) {
            createInnerButton()
                .constraints(constraints)
                .background(self.model.backgroundColor)
                .border(self.model.border)
        }
        .buttonClick(self.model.identifier, behaviors: self.model.clickBehaviors, actions: nil)
        .enableButton(self.model.enableBehaviors)
    }
    
    @ViewBuilder
    private func createInnerButton() -> some View {
        switch(model.image) {
        case .url(let model):
            createImage(model)
        case .icon(let model):
            createIcon(model)
        }
    }
    @ViewBuilder
    private func createImage(_ model: ImageURLModel) -> some View {
        Image(uiImage: image)
            .renderingMode(.original)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .onReceive(imageLoader.loaded) { data in
                self.image = UIImage(data: data) ?? UIImage()
            }
            .onAppear {
                self.imageLoaderCancellable = imageLoader.load(url: model.url)
            }
    }
    
    @ViewBuilder
    private func createIcon(_ model: IconModel) -> some View {
        Icons.icon(model: model, colorScheme: colorScheme)
    }
}
