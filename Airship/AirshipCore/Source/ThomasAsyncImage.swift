/* Copyright Airship and Contributors */

import Combine
import Foundation
import SwiftUI

public struct ThomasAsyncImage<Placeholder: View, ImageView: View>: View {

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
    @State private var imageTask: Task<Void, Never>?
    @State private var cancellable: AnyCancellable?

    @Environment(\.isVisible) var isVisible: Bool   // we use this value not for updating view tree, but for starting stopping animation,
                                                    //that's why we need to store the actual value in a separate @State variable
    @State private var isImageVisible: Bool = false

    public var body: some View {
        content
            .onAppear {
                if self.loadedImage != nil {
                    animateIfNeeded()
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
                                animateIfNeeded()
                            }
                        )
                }
            }
            .onChange(of: isVisible, perform: { newValue in
                self.isImageVisible = newValue
                animateIfNeeded()
            })
    }

    private var content: some View {
        Group {
            if let image = currentImage {
                self.image(Image(uiImage: image), image.size)
                    .animation(nil, value: self.imageIndex)
                    .onDisappear {
                        imageTask?.cancel()
                    }
            } else {
                self.placeholder()
            }
        }
    }

    private func animateIfNeeded() {
        self.imageTask?.cancel()

        if isImageVisible {
            self.imageTask = Task {
                await animateImage()
            }
        } else {
            self.imageTask = Task {
                await preloadFirstImage()
            }
        }
    }

    @MainActor
    private func preloadFirstImage() async {
        guard let loadedImage = self.loadedImage, self.currentImage == nil else { return }

        guard loadedImage.isAnimated else {
            self.currentImage = loadedImage.loadFrames().first?.image
            return
        }

        let image = await loadedImage.getActor().loadFrame(at: 0)?.image
        if !Task.isCancelled {
            self.currentImage = image
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
