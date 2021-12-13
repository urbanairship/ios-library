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
    @State private var cancellable: AnyCancellable?
    @EnvironmentObject var thomasEnvironment: ThomasEnvironment

    var body: some View {
        content
            .onAppear {
                if (self.loadedImage != nil) {
                    animateImage()
                } else {
                    self.cancellable = thomasEnvironment.imageLoader.load(url: self.url)
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
                self.image(Image(uiImage: image))
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

@available(iOS 13.0.0, tvOS 13.0.0, *)
extension Image {
    
    @ViewBuilder
    func fitMedia(mediaFit:MediaFit, width: CGFloat?, height: CGFloat?) -> some View {
        switch mediaFit {
        case .center:
            center(width: width, height: height)
        case .centerCrop:
            centerCrop(width: width, height: height)
        case .centerInside:
            centerInside(width: width, height: height)
        }
    }
    
    func center(width: CGFloat?, height: CGFloat?) -> some View {
        self
            .frame(width: width, height: height, alignment: .center)
            .clipped()
    }
    
    func centerCrop(width: CGFloat?, height: CGFloat?) -> some View {
        self
            .resizable()
            .scaledToFill()
            .frame(width: width, height: height, alignment: .center)
            .clipped()
    }
    
    func centerInside(width: CGFloat?, height: CGFloat?) -> some View {
        self
            .resizable()
            .scaledToFit()
            .frame(width: width, height: height, alignment: .center)
    }
}
