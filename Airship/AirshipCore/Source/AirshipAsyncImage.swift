/* Copyright Airship and Contributors */

import Combine
import Foundation
import SwiftUI

/// - Note: for internal use only.  :nodoc:
public struct AirshipAsyncImage<Placeholder: View, ImageView: View>: View {

    let url: String
    let imageLoader: AirshipImageLoader
    let image: (Image, CGSize) -> ImageView
    let placeholder: () -> Placeholder

    public init(
        url: String,
        imageLoader: AirshipImageLoader = AirshipImageLoader(),
        image: @escaping (Image, CGSize) -> ImageView,
        placeholder: @escaping () -> Placeholder
    ) {
        self.url = url
        self.imageLoader = imageLoader
        self.image = image
        self.placeholder = placeholder
    }

    @State private var loadedImage: AirshipImageData? = nil
    @State private var currentImage: UIImage?
    @State private var imageIndex: Int = 0
    @State private var animationTask: Task<Void, Never>?
    @State private var cancellable: AnyCancellable?

    public var body: some View {
        content
            .onAppear {
                if self.loadedImage != nil {
                    startAnimation()
                } else {
                    self.cancellable = self.imageLoader.load(url: self.url)
                        .receive(on: DispatchQueue.main)
                        .sink(
                            receiveCompletion: { completion in
                                if case let .failure(error) = completion {
                                    AirshipLogger.error(
                                        "Unable to load image \(error)"
                                    )
                                }
                            },
                            receiveValue: { image in
                                self.loadedImage = image
                                startAnimation()
                            }
                        )
                }
            }
    }

    private var content: some View {
        Group {
            if let image = currentImage {
                self.image(Image(uiImage: image), image.size)
                    .animation(nil, value: self.imageIndex)
                    .onDisappear {
                        animationTask?.cancel()
                    }
            } else {
                self.placeholder()
            }
        }
    }

    private func startAnimation() {
        self.animationTask?.cancel()
        self.animationTask = Task { @MainActor in
            await animateImage()
        }
    }

    @MainActor
    private func animateImage() async {
        guard let loadedImage = self.loadedImage else { return }
        
        guard loadedImage.isAnimated else {
            self.currentImage = loadedImage.loadFrames().first?.image
            return
        }
        
        let frameActor = loadedImage.getActor()

        imageIndex = 0
        var frame = await frameActor.loadFrame(at: imageIndex)

        self.currentImage = frame?.image

        while !Task.isCancelled {
            let duration = frame?.duration ?? AirshipImageData.minFrameDuration
            
            async let delay: () = Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
            
            let nextIndex = (imageIndex + 1) % loadedImage.imageFramesCount
            
            do {
                let (_, nextFrame) = try await (delay, frameActor.loadFrame(at: nextIndex))
                frame = nextFrame
            } catch {} // most likely it's a task cancelled exception when animation is stopped

            imageIndex = nextIndex

            if !Task.isCancelled {
                self.currentImage = frame?.image
            }
        }
    }
}
