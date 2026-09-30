/* Copyright Airship and Contributors */

#if !os(macOS) && !os(watchOS) && !os(tvOS)

import Combine
import Foundation
import SwiftUI
import Testing
import UIKit

@_spi(AirshipInternal) import AirshipBasement
@testable @_spi(AirshipInternal) import AirshipSceneRenderer

/// Renders a wrapping score and reads its rows off the pixels, through a width change on the same view.
@MainActor
@Suite("Score wrapping rendering")
struct ScoreWrappingRenderingTest {

    private final class StubThomasDelegate: ThomasDelegate {
        func onVisibilityChanged(isVisible: Bool, isForegrounded: Bool) {}
        func onReportingEvent(_ event: ThomasReportingEvent) {}
        func onDismissed(cancel: Bool) {}
        func onStateChanged(_ state: AirshipJSON) {}
    }

    private final class Width: ObservableObject {
        @Published var value: CGFloat
        init(_ value: CGFloat) { self.value = value }
    }

    private struct Host: View {
        @ObservedObject var width: Width
        let view: ThomasViewInfo
        let thomasEnvironment: ThomasEnvironment
        let thomasState: ThomasState
        let formState: ThomasFormState
        let formDataCollector: ThomasFormDataCollector
        let validatableHelper: ValidatableHelper

        var body: some View {
            thomasEnvironment.viewFactory.createView(view, constraints: ViewConstraints(width: width.value, height: 400))
                .frame(width: width.value, height: 400, alignment: .top)
                .background(Color.white)
                .environmentObject(thomasEnvironment)
                .environmentObject(thomasState)
                .environmentObject(formState)
                .environmentObject(formDataCollector)
                .environmentObject(validatableHelper)
        }
    }

    private let thomasEnvironment = ThomasEnvironment(delegate: StubThomasDelegate(), extensions: TestThomasExtensions())
    private let thomasState = ThomasState(onStateChange: { _ in })
    private let formState = ThomasFormState(identifier: "form", formType: .form, formResponseType: nil, validationMode: .onDemand)
    private let formDataCollector = ThomasFormDataCollector()
    private let validatableHelper = ValidatableHelper()

    private static let score = #"""
    {"type": "linear_layout", "direction": "vertical", "items": [{
      "size": {"width": "100%", "height": "auto"},
      "view": {"type": "linear_layout", "direction": "horizontal", "items": [{
      "size": {"width": "100%", "height": "auto"},
      "view": {
        "type": "score",
        "identifier": "nps",
        "style": {
          "type": "number_range", "start": 0, "end": 10, "spacing": 2,
          "wrapping": {"line_spacing": 16, "max_items_per_line": 6},
          "bindings": {
            "selected": {
              "shapes": [{"type": "rectangle", "color": {"default": {"type": "hex", "hex": "#0000FF", "alpha": 1}}}],
              "text_appearance": {"font_size": 24, "color": {"default": {"type": "hex", "hex": "#FFFFFF", "alpha": 1}}}
            },
            "unselected": {
              "shapes": [{"type": "rectangle", "color": {"default": {"type": "hex", "hex": "#FF0000", "alpha": 1}}}],
              "text_appearance": {"font_size": 24, "color": {"default": {"type": "hex", "hex": "#FFFFFF", "alpha": 1}}}
            }
          }
        }
      }
    }]}
    }]}
    """#

    /// The rows of red score items drawn, as (top, height), scanning every pixel row.
    private func drawnRows(_ renderer: ImageRenderer<Host>, width: Int) throws -> [(Int, Int)] {
        let image = try #require(renderer.cgImage)
        let height = 400
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        let context = try #require(CGContext(
            data: &pixels,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ))
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))

        let hasRed = (0..<height).map { y in
            (0..<width).contains { x in
                let offset = (y * width + x) * 4
                return pixels[offset] > 240 && pixels[offset + 1] < 20 && pixels[offset + 2] < 20
            }
        }
        var rows: [(Int, Int)] = []
        var start: Int?
        for (y, red) in (hasRed + [false]).enumerated() {
            if red, start == nil { start = y }
            if !red, let top = start {
                rows.append((top, y - top))
                start = nil
            }
        }
        return rows
    }

    private func settle(_ renderer: ImageRenderer<Host>) async throws {
        for _ in 0..<6 {
            _ = renderer.cgImage
            try await Task.sleep(for: .milliseconds(30))
        }
    }

    @Test("a wrapping score in an auto-height stack takes the rows its current width needs")
    func growsWhenNarrowed() async throws {
        let view = try JSONDecoder().decode(ThomasViewInfo.self, from: Data(Self.score.utf8))
        let width = Width(400)
        let renderer = ImageRenderer(content: Host(
            width: width,
            view: view,
            thomasEnvironment: thomasEnvironment,
            thomasState: thomasState,
            formState: formState,
            formDataCollector: formDataCollector,
            validatableHelper: validatableHelper
        ))
        renderer.scale = 1

        try await settle(renderer)
        let wide = try drawnRows(renderer, width: 400)

        width.value = 260
        try await settle(renderer)
        let narrow = try drawnRows(renderer, width: 260)

        width.value = 400
        try await settle(renderer)
        let widenedAgain = try drawnRows(renderer, width: 400)

        #expect(wide.count == 2)
        #expect(narrow.count == 3)
        // Every row is drawn whole, the same height as the first, starting at the top.
        #expect(narrow.allSatisfy { $0.1 == wide.first?.1 })
        #expect(narrow.first?.0 == 0)
        #expect(widenedAgain.map(\.1) == wide.map(\.1))
        #expect(widenedAgain.first?.0 == 0)
    }
}

#endif
