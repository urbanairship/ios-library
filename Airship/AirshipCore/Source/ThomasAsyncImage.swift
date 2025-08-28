/* Copyright Airship and Contributors */

import Combine

public import SwiftUI

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
    @State private var loopsCompleted: Int = 0

    @Environment(\.isVisible) var isVisible: Bool   // we use this value not for updating view tree, but for starting stopping animation,
                                                    //that's why we need to store the actual value in a separate @State variable
    @State private var isImageVisible: Bool = false

    public var body: some View {
        content
            .onAppear {
                self.isImageVisible = self.isVisible
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
            .airshipOnChangeOf(isVisible) { newValue in
                self.isImageVisible = newValue
                if newValue {
                    self.loopsCompleted = 0 // Reset gif frame loop counter every time isVisible changes
                }
                animateIfNeeded()
            }
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
            self.imageTask = Task { @MainActor in
                await animateImage()
            }
        } else {
            self.imageTask = Task { @MainActor in
                await preloadFirstImage()
            }
        }
    }

    @MainActor
    private func preloadFirstImage() async {
        guard let loadedImage = self.loadedImage, self.currentImage == nil else { return }

        guard loadedImage.isAnimated else {
            self.currentImage = await loadedImage.loadFrames().first?.image
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
            self.currentImage = await loadedImage.loadFrames().first?.image
            return
        }

        let frameActor = loadedImage.getActor()

        imageIndex = 0
        var frame = await frameActor.loadFrame(at: imageIndex)

        self.currentImage = frame?.image

        /// GIFs will sometimes have a 0 in their loop count metadata to denote infinite loops
        let loopCount = loadedImage.loopCount ?? 0

        /// Continue looping if loop count is nil (coalesces to zero), zero or nonzero and greater than the loops completed
        while !Task.isCancelled && (loopCount <= 0 || loopCount > loopsCompleted) {
            let duration = frame?.duration ?? AirshipImageData.minFrameDuration

            async let delay: () = Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))

            let nextIndex = (imageIndex + 1) % loadedImage.imageFramesCount

            do {
                let (_, nextFrame) = try await (delay, frameActor.loadFrame(at: nextIndex))
                frame = nextFrame
            } catch {} // most likely it's a task cancelled exception when animation is stopped

            imageIndex = nextIndex

            /// Consider a loop completed when we reach the last frame
            if imageIndex == loadedImage.imageFramesCount - 1 {
                /// Stops the GIF when loopsCompleted == loopCount when loopCount is specified
                self.loopsCompleted += 1
            }

            if !Task.isCancelled {
                self.currentImage = frame?.image
            }
        }
    }
}
