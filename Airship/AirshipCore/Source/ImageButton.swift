/* Copyright Airship and Contributors */

import Foundation
import SwiftUI
import Combine

/// Image Button view.
@available(iOS 13.0.0, tvOS 13.0, *)
struct ImageButton : View {
 
    var imageLoaderCancellable: AnyCancellable? = nil
    
    /// Image Button model.
    let model: ImageButtonModel
  
    /// View constriants.
    let constraints: ViewConstraints
  
    @ObservedObject var imageLoader:AssetLoader
    @State var image:UIImage = UIImage()

    init(model:ImageButtonModel, constraints:ViewConstraints) {
        self.imageLoader = AssetLoader()
        self.model = model
        self.constraints = constraints
        imageLoaderCancellable = imageLoader.load(url: model.url)
    }
    
    var body: some View {
        Button(action: {
            print("Button action")
        }) {
                Image(uiImage: image)
                .renderingMode(.original)
                .aspectRatio(contentMode: .fit)
                .onReceive(imageLoader.loaded) { data in
                    self.image = UIImage(data: data) ?? UIImage()
                }
        }
        .frame(width: constraints.width, height: constraints.height)
    }
}
