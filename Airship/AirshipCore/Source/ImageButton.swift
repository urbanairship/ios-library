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
    
    @ViewBuilder
    var body: some View {
        Button(action: {
            print("Button action")
        }) {
            switch(model.image) {
            case .url(let model):
                createImage(model)
                
            case .icon(let model):
                createIcon(model)
            }
        }
        .background(self.model.backgroundColor)
        .border(self.model.border)
        .constraints(constraints)
    }
    
    @ViewBuilder
    private func createImage(_ model: UrlButtonImageModel) -> some View {
        Image(uiImage: image)
            .renderingMode(.original)
            .aspectRatio(contentMode: .fit)
            .onReceive(imageLoader.loaded) { data in
                self.image = UIImage(data: data) ?? UIImage()
            }
            .onAppear {
                self.imageLoaderCancellable = imageLoader.load(url: model.url)
            }
    }
    
    @ViewBuilder
    private func createIcon(_ model: IconButtonImageModel) -> some View {
        switch(model.icon) {
        case .close:
            Image(systemName: "xmark")
                .aspectRatio(contentMode: .fit)
                .foregroundColor(model.tint.toColor())
        }
    }
}
