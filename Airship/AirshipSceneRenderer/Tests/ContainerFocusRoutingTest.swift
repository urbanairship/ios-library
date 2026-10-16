/* Copyright Airship and Contributors */

import CoreGraphics
import Foundation
import Testing

@testable @_spi(AirshipInternal) import AirshipSceneRenderer

@Suite("Container focus routing")
struct ContainerFocusRoutingTest {

    private let big = CGRect(x: 0, y: 0, width: 400, height: 300)
    private let closeAtTopEnd = CGRect(x: 320, y: 0, width: 80, height: 60)

    private func target(
        from index: Int,
        _ direction: ContainerFocusDirection,
        _ frames: [Int: CGRect]
    ) -> Int? {
        ContainerFocusRouting.target(from: index, direction: direction, frames: frames)
    }

    @Test("an item drawn inside another is reached by moving toward it")
    func reachesOverlappedItem() {
        let frames = [0: big, 1: closeAtTopEnd]
        #expect(target(from: 0, .up, frames) == 1)
        #expect(target(from: 0, .right, frames) == 1)
    }

    @Test("no move away from the overlapping item is routed")
    func ignoresOppositeDirections() {
        let frames = [0: big, 1: closeAtTopEnd]
        #expect(target(from: 0, .down, frames) == nil)
        #expect(target(from: 0, .left, frames) == nil)
    }

    @Test("the overlapping item routes back to the item beneath it")
    func routesBack() {
        let frames = [0: big, 1: closeAtTopEnd]
        #expect(target(from: 1, .down, frames) == 0)
        #expect(target(from: 1, .left, frames) == 0)
        #expect(target(from: 1, .up, frames) == nil)
        #expect(target(from: 1, .right, frames) == nil)
    }

    @Test("items that don't overlap are left to the system")
    func ignoresNonOverlapping() {
        let frames = [0: big, 1: CGRect(x: 500, y: 0, width: 80, height: 60)]
        #expect(target(from: 0, .right, frames) == nil)
        #expect(target(from: 1, .left, frames) == nil)
    }

    @Test("frames that only share an edge don't count as overlapping")
    func edgeContactIsNotOverlap() {
        let frames = [0: big, 1: CGRect(x: 400, y: 0, width: 80, height: 60)]
        #expect(target(from: 0, .right, frames) == nil)
    }

    @Test("the nearest qualifying item wins")
    func nearestWins() {
        let nearer = CGRect(x: 300, y: 20, width: 80, height: 60)
        let farther = CGRect(x: 340, y: 0, width: 60, height: 40)
        let frames = [0: big, 1: farther, 2: nearer]
        #expect(target(from: 0, .up, frames) == 2)
    }

    @Test("equally near items resolve to the one drawn on top")
    func tiesGoToTheTopmost() {
        let a = CGRect(x: 320, y: 0, width: 80, height: 60)
        let frames = [0: big, 1: a, 2: a]
        #expect(target(from: 0, .up, frames) == 2)
    }

    @Test("an item with no frame yet routes nowhere")
    func missingFrame() {
        #expect(target(from: 0, .up, [1: closeAtTopEnd]) == nil)
    }

    private func view(_ json: String) throws -> ThomasViewInfo {
        let layout = """
        {"version": 1,
         "presentation": {"type": "modal", "default_placement": {"size": {"width": "100%", "height": "100%"}}},
         "view": \(json)}
        """
        return try JSONDecoder().decode(AirshipLayout.self, from: Data(layout.utf8)).view
    }

    private let label = """
    {"type": "label", "text": "x", "text_appearance": {"font_size": 12, "alignment": "start", "color": {"default": {"hex": "#000000"}}}}
    """

    private func item(_ view: String) -> String {
        """
        {"position": {"horizontal": "center", "vertical": "center"}, "size": {"width": "auto", "height": "auto"}, "view": \(view)}
        """
    }

    @Test("a label is not focusable")
    func labelIsNotFocusable() throws {
        #expect(try view(label).containsFocusableControl == false)
    }

    @Test("a button is focusable")
    func buttonIsFocusable() throws {
        let button = """
        {"type": "image_button", "identifier": "close", "button_click": ["dismiss"],
         "image": {"type": "icon", "icon": "close", "scale": 1, "color": {"default": {"hex": "#000000"}}}}
        """
        #expect(try view(button).containsFocusableControl == true)
    }

    @Test("a container of labels is not focusable")
    func containerOfLabels() throws {
        let container = """
        {"type": "container", "items": [\(item(label))]}
        """
        #expect(try view(container).containsFocusableControl == false)
    }

    @Test("a button nested in layouts makes every ancestor focusable")
    func nestedButton() throws {
        let button = """
        {"type": "label_button", "identifier": "b", "label": \(label)}
        """
        let linear = """
        {"type": "linear_layout", "direction": "vertical", "items": [\(item(button))]}
        """
        let container = """
        {"type": "container", "items": [\(item(linear))]}
        """
        #expect(try view(container).containsFocusableControl == true)
    }
}
