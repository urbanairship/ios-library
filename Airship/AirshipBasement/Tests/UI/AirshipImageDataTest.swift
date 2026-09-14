/* Copyright Airship and Contributors */

import Testing
@_spi(AirshipInternal) @testable import AirshipBasement
import ImageIO
import UniformTypeIdentifiers

@Suite struct AirshipImageDataTest {

    @Test
    func testUnclampedFrameDelay() async throws {
        // The unclamped key preserves the authored delay even when the
        // clamped key would round it up.
        let data = try Self.makeAnimatedGIF(frameDelays: [0.01, 0.01])
        let imageData = try AirshipImageData(data: data)

        let frames = await imageData.loadFrames()

        #expect(frames.count == 2)
        for frame in frames {
            #expect(abs(frame.duration - 0.01) < 0.0001)
        }
    }

    @Test
    func testFrameDelay() async throws {
        let data = try Self.makeAnimatedGIF(frameDelays: [0.5, 0.25])
        let imageData = try AirshipImageData(data: data)

        let frames = await imageData.loadFrames()

        #expect(frames.count == 2)
        #expect(abs(frames[0].duration - 0.5) < 0.0001)
        #expect(abs(frames[1].duration - 0.25) < 0.0001)
    }

    @Test
    func testZeroFrameDelayUsesClampedDelay() async throws {
        // A 0 delay is almost always unintentional; expect the clamped
        // delay (0.1 s, matching browser behavior) instead of the floor.
        let data = try Self.makeAnimatedGIF(frameDelays: [0.0, 0.0])
        let imageData = try AirshipImageData(data: data)

        let frames = await imageData.loadFrames()

        #expect(frames.count == 2)
        for frame in frames {
            #expect(abs(frame.duration - 0.1) < 0.0001)
        }
    }

    private static func makeAnimatedGIF(frameDelays: [TimeInterval]) throws -> Data {
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            data,
            UTType.gif.identifier as CFString,
            frameDelays.count,
            nil
        ) else {
            throw AirshipErrors.error("Failed to create image destination")
        }

        for delay in frameDelays {
            let frameProperties = [
                kCGImagePropertyGIFDictionary: [
                    kCGImagePropertyGIFDelayTime: delay,
                    kCGImagePropertyGIFUnclampedDelayTime: delay
                ]
            ] as CFDictionary

            CGImageDestinationAddImage(
                destination,
                try makeFrameImage(),
                frameProperties
            )
        }

        guard CGImageDestinationFinalize(destination) else {
            throw AirshipErrors.error("Failed to finalize GIF")
        }

        return data as Data
    }

    private static func makeFrameImage() throws -> CGImage {
        guard
            let context = CGContext(
                data: nil,
                width: 1,
                height: 1,
                bitsPerComponent: 8,
                bytesPerRow: 0,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ),
            let image = context.makeImage()
        else {
            throw AirshipErrors.error("Failed to create frame image")
        }
        return image
    }
}
