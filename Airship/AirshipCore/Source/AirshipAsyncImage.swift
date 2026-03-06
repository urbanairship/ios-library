/* Copyright Airship and Contributors */

import Foundation
public import SwiftUI

/// - Note: for internal use only.  :nodoc:
public struct AirshipAsyncImage<Placeholder: View, ImageView: View>: View {

    private let url: String
    private let imageLoader: AirshipImageLoader
    private let image: (Image, CGSize) -> ImageView
    private let placeholder: () -> Placeholder

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

    @State private var loadedURL: String?
    @State private var loadedImage: AirshipImageData?
    @State private var currentImage: UIImage?
    @State private var imageIndex: Int = 0
    @State private var animationTask: Task<Void, Never>?

    public var body: some View {
        content
            .task(id: url) {
                guard loadedURL != url else {
                    startAnimation()
                    return
                }

                self.loadedImage = nil
                self.currentImage = nil

                do {
                    let image = try await imageLoader.load(url: url)
                    self.loadedURL = url
                    self.loadedImage = image
                    startAnimation()
                } catch is CancellationError {
                } catch {
                    AirshipLogger.error("Unable to load image \(url): \(error)")
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
            self.currentImage = await loadedImage.loadFrames().first?.image
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
