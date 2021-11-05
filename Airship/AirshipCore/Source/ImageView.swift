/* Copyright Airship and Contributors */

import Foundation
import SwiftUI

@available(iOS 13.0.0, tvOS 13.0, *)
struct ImageView: UIViewRepresentable {
    
    typealias UIViewType = UIImageView
    
    let url: String
    
    @available(iOS 13.0.0, tvOS 13.0, *)
    func makeUIView(context: Context) -> UIImageView {
        return createImageView()
    }
    
    func updateUIView(_ uiView: UIImageView, context: Context) {
    }
    
    func createImageView() -> UIImageView {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        imageView.setContentCompressionResistancePriority(.defaultLow, for: .vertical)


        guard let mediaUrl = URL(string:url) else { return imageView}
        ///Fetch Image Data
        if let data = try? Data(contentsOf:mediaUrl) {
            imageView.image = UIImage.fancyImage(with:data)
        }
        return imageView
        
    }
}
