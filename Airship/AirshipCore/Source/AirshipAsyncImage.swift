/* Copyright Airship and Contributors */


import Foundation
import SwiftUI
import Combine

/// - Note: for internal use only.  :nodoc:
@available(iOS 13.0.0, tvOS 13.0.0, *)
public struct AirshipAsyncImage<Placeholder: View, ImageView: View> : View {
    
    let url: String
    let imageLoader: ImageLoader
    let image: (Image, CGSize) -> ImageView
    let placeholder: () -> Placeholder


    public init(url: String,
         imageLoader: ImageLoader = ImageLoader(),
         image: @escaping (Image, CGSize) -> ImageView,
         placeholder: @escaping () -> Placeholder) {
        self.url = url
        self.imageLoader = imageLoader
        self.image = image
        self.placeholder = placeholder
    }

    @State private var loadedImage: UIImage?
    @State private var currentImage: UIImage?
    @State private var imageIndex: Int = 0
    @State private var timer: Timer?
    @State private var cancellable: AnyCancellable?

    public var body: some View {
        content
            .onAppear {
                if (self.loadedImage != nil) {
                    animateImage()
                } else {
                    self.cancellable = self.imageLoader.load(url: self.url)
                        .receive(on: DispatchQueue.main)
                        .sink(receiveCompletion: { completion in
                            if case let .failure(error) = completion {
                                AirshipLogger.error("Unable to load image \(error)")
                            }
                        }, receiveValue: { image in
                            self.loadedImage = image
                            self.animateImage()
                        })
                }
            }
            .onDisappear {
                timer?.invalidate()
            }
    }
    
    private var content: some View {
        Group {
            if let image = currentImage {
                self.image(Image(uiImage: image), image.size)
            } else {
                self.placeholder()
            }
        }
    }
    
    private func animateImage() {
        guard let loadedImage = self.loadedImage else {
            return
        }
        
        let duration = loadedImage.duration
        
        guard let frames = loadedImage.images, duration > 0 && frames.count > 1 else {
            self.currentImage = loadedImage
            return
        }
        
        self.timer = Timer(timeInterval: duration/Double(frames.count), repeats: true) { timer in
            if (self.imageIndex >= (frames.count - 1)) {
                self.imageIndex = 0
            } else {
                self.imageIndex += 1
            }
            
            self.currentImage = frames[self.imageIndex];
        }
        
        
        if let timer = timer {
            RunLoop.main.add(timer, forMode: .common)
        }
        
    }
}
