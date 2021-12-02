/* Copyright Airship and Contributors */


import Foundation
import SwiftUI
import Combine

@available(iOS 13.0.0, tvOS 13.0.0, *)
struct AirshipAsyncImage<Placeholder: View, ImageView: View> : View {
    
    let url: String
    let image: (Image) -> ImageView
    let placeholder: () -> Placeholder
    
    @State private var loadedImage: UIImage?
    @State private var currentImage: UIImage?
    @State private var imageIndex: Int = 0
    @State private var timer: Timer?

    @State private var imageLoader: AssetLoader = AssetLoader()
    @State private var imageLoaderCancellable: AnyCancellable?
    
    var body: some View {
        content
            .onReceive(imageLoader.loaded) { image in
                if let image = image {
                    self.loadedImage = image
                    animateImage()
                }
            }
            .onAppear {
                if self.loadedImage != nil {
                    animateImage()
                } else {
                    self.imageLoaderCancellable = imageLoader.load(url: self.url)
                }
            }
            .onDisappear {
                timer?.invalidate()
            }
    }
    
    private var content: some View {
        Group {
            if let image = currentImage {
                self.image(Image(uiImage: image))
            } else {
                self.placeholder()
            }
        }
    }
    
    private func animateImage() {
        guard let loadedImage = loadedImage else {
            return
        }
        
        let duration = loadedImage.duration
        
        guard let frames = loadedImage.images, duration > 0 && frames.count > 1 else {
            self.currentImage = loadedImage
            return
        }
        
        self.timer = Timer.scheduledTimer(withTimeInterval: duration/Double(frames.count), repeats: true) { timer in
            if (self.imageIndex >= (frames.count - 1)) {
                self.imageIndex = 0
            } else {
                self.imageIndex += 1
            }
            
            self.currentImage = frames[self.imageIndex];
        }
    }
}
