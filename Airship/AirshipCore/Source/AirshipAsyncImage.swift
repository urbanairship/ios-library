/* Copyright Airship and Contributors */


import Foundation
import SwiftUI
import Combine

@available(iOS 13.0.0, tvOS 13.0.0, *)
struct AirshipAsyncImage<Placeholder: View, ImageView: View> : View {
    
    let url: String
    let image: (Image, CGSize) -> ImageView
    let placeholder: () -> Placeholder

    @State private var loadedImage: AirshipImageData? = nil


    @State private var currentImage: UIImage?
    @State private var imageIndex: Int = 0
    @State private var animationTask: Task<Void, Never>?
    @State private var cancellable: AnyCancellable?
    @EnvironmentObject var thomasEnvironment: ThomasEnvironment

    var body: some View {
        content
            .onAppear {
                if (self.loadedImage != nil) {
                    self.animationTask?.cancel()
                    self.animationTask = Task {
                        await animateImage()
                    }
                } else {
                    self.cancellable = thomasEnvironment.imageLoader.load(url: self.url)
                        .receive(on: DispatchQueue.main)
                        .sink(receiveCompletion: { completion in
                            if case let .failure(error) = completion {
                                AirshipLogger.error("Unable to load image \(error)")
                            }
                        }, receiveValue: { image in
                            self.loadedImage = image
                            self.animationTask?.cancel()
                            self.animationTask = Task {
                                await animateImage()
                            }
                        })
                }
            }
            .onDisappear {
                animationTask?.cancel()
            }
    }
    
    private var content: some View {
        Group {
            if let image = currentImage {
                self.image(Image(uiImage: image), image.size)
                    .animation(nil, value: self.imageIndex)
            } else {
                self.placeholder()
            }
        }
    }

    @MainActor
    private func animateImage() async {
        guard let loadedImage = self.loadedImage else {
            return
        }

        guard loadedImage.frames.count > 1 else {
            self.currentImage = loadedImage.frames[0].image
            return
        }


        let frames = loadedImage.frames
        self.currentImage = frames[self.imageIndex].image

        while(!Task.isCancelled) {
            let duration = frames[self.imageIndex].duration
            try? await Task.sleep(
                nanoseconds: UInt64(duration * 1_000_000_000)
            )

            if (!Task.isCancelled) {
                if (self.imageIndex >= (frames.count - 1)) {
                    self.imageIndex = 0
                } else {
                    self.imageIndex += 1
                }

                self.currentImage = frames[self.imageIndex].image
            }
        }

        
    }
}
