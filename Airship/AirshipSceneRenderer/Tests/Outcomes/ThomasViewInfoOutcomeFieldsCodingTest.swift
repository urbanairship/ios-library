/* Copyright Airship and Contributors */

import Foundation
import Testing

@testable import AirshipBasement
@testable @_spi(AirshipInternal) import AirshipSceneRenderer

@Suite("Outcomes", .timeLimit(.minutes(1)))
struct ThomasViewInfoOutcomeFieldsCodingTest {

    private let decoder = JSONDecoder()

    private let labelFragment = """
    "label": {
      "type": "label",
      "text": "ok",
      "text_appearance": {
        "font_size": 10,
        "alignment": "center",
        "color": {
          "default": {
            "type": "hex",
            "hex": "#000000",
            "alpha": 1
          }
        }
      }
    }
    """

    private let backgroundColor = """
    "background_color": {
      "default": {
        "type": "hex",
        "hex": "#D32F2F",
        "alpha": 1
      }
    }
    """

    @Test
    func labelButtonDecodesOutcomesWhenPresent() throws {
        let json = """
        {
          "type": "label_button",
          "identifier": "lb1",
          \(backgroundColor),
          \(labelFragment),
          "outcomes": [
            { "type": "dismiss", "cancel": false, "identifier": "dec.dismiss.false" }
          ]
        }
        """
        let view = try decoder.decode(ThomasViewInfo.self, from: Data(json.utf8))
        guard case .labelButton(let button) = view else {
            Issue.record("Expected labelButton")
            return
        }
        #expect(button.properties.outcomes?.count == 1)
    }

    @Test
    func labelButtonOutcomesNilWhenAbsent() throws {
        let json = """
        {
          "type": "label_button",
          "identifier": "lb1",
          \(backgroundColor),
          \(labelFragment)
        }
        """
        let view = try decoder.decode(ThomasViewInfo.self, from: Data(json.utf8))
        guard case .labelButton(let button) = view else {
            Issue.record("Expected labelButton")
            return
        }
        #expect(button.properties.outcomes == nil)
    }

    @Test
    func imageButtonDecodesOutcomesWhenPresent() throws {
        let json = """
        {
          "type": "image_button",
          "identifier": "ib1",
          "image": {
            "scale": 0.4,
            "type": "icon",
            "icon": "close",
            "color": {
              "default": {
                "type": "hex",
                "hex": "#000000",
                "alpha": 1
              }
            }
          },
          "outcomes": [
            { "type": "dismiss", "cancel": true, "identifier": "dec.dismiss.true" }
          ]
        }
        """
        let view = try decoder.decode(ThomasViewInfo.self, from: Data(json.utf8))
        guard case .imageButton(let button) = view else {
            Issue.record("Expected imageButton")
            return
        }
        #expect(button.properties.outcomes?.count == 1)
    }

    @Test
    func imageButtonOutcomesNilWhenAbsent() throws {
        let json = """
        {
          "type": "image_button",
          "identifier": "ib1",
          "image": {
            "scale": 0.4,
            "type": "icon",
            "icon": "close",
            "color": {
              "default": {
                "type": "hex",
                "hex": "#000000",
                "alpha": 1
              }
            }
          }
        }
        """
        let view = try decoder.decode(ThomasViewInfo.self, from: Data(json.utf8))
        guard case .imageButton(let button) = view else {
            Issue.record("Expected imageButton")
            return
        }
        #expect(button.properties.outcomes == nil)
    }

    @Test
    func stackImageButtonDecodesOutcomesWhenPresent() throws {
        let json = """
        {
          "type": "stack_image_button",
          "identifier": "sib1",
          "items": [
            {
              "type": "icon",
              "icon": {
                "type": "icon",
                "icon": "close",
                "scale": 0.4,
                "color": {
                  "default": {
                    "type": "hex",
                    "hex": "#000000",
                    "alpha": 1
                  }
                }
              }
            }
          ],
          "outcomes": [
            { "type": "dismiss", "cancel": false, "identifier": "dec.dismiss.false" }
          ]
        }
        """
        let view = try decoder.decode(ThomasViewInfo.self, from: Data(json.utf8))
        guard case .stackImageButton(let button) = view else {
            Issue.record("Expected stackImageButton")
            return
        }
        #expect(button.properties.outcomes?.count == 1)
    }

    @Test
    func stackImageButtonOutcomesNilWhenAbsent() throws {
        let json = """
        {
          "type": "stack_image_button",
          "identifier": "sib1",
          "items": [
            {
              "type": "icon",
              "icon": {
                "type": "icon",
                "icon": "close",
                "scale": 0.4,
                "color": {
                  "default": {
                    "type": "hex",
                    "hex": "#000000",
                    "alpha": 1
                  }
                }
              }
            }
          ]
        }
        """
        let view = try decoder.decode(ThomasViewInfo.self, from: Data(json.utf8))
        guard case .stackImageButton(let button) = view else {
            Issue.record("Expected stackImageButton")
            return
        }
        #expect(button.properties.outcomes == nil)
    }

    @Test
    func buttonLayoutDecodesOutcomesWhenPresent() throws {
        let json = """
        {
          "type": "button_layout",
          "identifier": "bl1",
          "view": {
            "type": "empty_view",
            "background_color": {
              "default": {
                "type": "hex",
                "hex": "#00FF00",
                "alpha": 0.5
              }
            }
          },
          "outcomes": [
            { "type": "dismiss", "cancel": false, "identifier": "dec.dismiss.false" }
          ]
        }
        """
        let view = try decoder.decode(ThomasViewInfo.self, from: Data(json.utf8))
        guard case .buttonLayout(let layout) = view else {
            Issue.record("Expected buttonLayout")
            return
        }
        #expect(layout.properties.outcomes?.count == 1)
    }

    @Test
    func buttonLayoutOutcomesNilWhenAbsent() throws {
        let json = """
        {
          "type": "button_layout",
          "identifier": "bl1",
          "view": {
            "type": "empty_view",
            "background_color": {
              "default": {
                "type": "hex",
                "hex": "#00FF00",
                "alpha": 0.5
              }
            }
          }
        }
        """
        let view = try decoder.decode(ThomasViewInfo.self, from: Data(json.utf8))
        guard case .buttonLayout(let layout) = view else {
            Issue.record("Expected buttonLayout")
            return
        }
        #expect(layout.properties.outcomes == nil)
    }

    @Test
    func pagerItemDecodesDisplayOutcomes() throws {
        let json = """
        {
          "type": "pager",
          "items": [
            {
              "identifier": "page1",
              "display_outcomes": [
                { "type": "dismiss", "cancel": false, "identifier": "dec.dismiss.false" }
              ],
              "view": {
                "type": "empty_view",
                "background_color": {
                  "default": {
                    "type": "hex",
                    "hex": "#00FF00",
                    "alpha": 0.5
                  }
                }
              }
            }
          ]
        }
        """
        let view = try decoder.decode(ThomasViewInfo.self, from: Data(json.utf8))
        guard case .pager(let pager) = view else {
            Issue.record("Expected pager")
            return
        }
        #expect(pager.properties.items.first?.displayOutcomes?.count == 1)
    }

    @Test
    func pagerItemDisplayOutcomesNilWhenAbsent() throws {
        let json = """
        {
          "type": "pager",
          "items": [
            {
              "identifier": "page1",
              "view": {
                "type": "empty_view",
                "background_color": {
                  "default": {
                    "type": "hex",
                    "hex": "#00FF00",
                    "alpha": 0.5
                  }
                }
              }
            }
          ]
        }
        """
        let view = try decoder.decode(ThomasViewInfo.self, from: Data(json.utf8))
        guard case .pager(let pager) = view else {
            Issue.record("Expected pager")
            return
        }
        #expect(pager.properties.items.first?.displayOutcomes == nil)
    }

    @Test
    func pagerSwipeDecodesOutcomesAndNilWithout() throws {
        let withOutcomes = """
        {
          "identifier": "sw1",
          "type": "swipe",
          "direction": "up",
          "outcomes": [
            { "type": "dismiss", "cancel": false, "identifier": "dec.dismiss.false" }
          ]
        }
        """
        let swipeOn = try decoder.decode(ThomasViewInfo.Pager.Gesture.self, from: Data(withOutcomes.utf8))
        guard case .swipeGesture(let s1) = swipeOn else {
            Issue.record("Expected swipe")
            return
        }
        #expect(s1.outcomes?.count == 1)

        let legacy = """
        {
          "identifier": "sw2",
          "type": "swipe",
          "direction": "up",
          "behavior": {
            "behaviors": ["dismiss"]
          }
        }
        """
        let swipeOff = try decoder.decode(ThomasViewInfo.Pager.Gesture.self, from: Data(legacy.utf8))
        guard case .swipeGesture(let s2) = swipeOff else {
            Issue.record("Expected swipe")
            return
        }
        #expect(s2.outcomes == nil)
        #expect(s2.behavior?.behaviors == [.dismiss])
    }

    @Test
    func pagerTapDecodesOutcomesAndNilWithout() throws {
        let withOutcomes = """
        {
          "identifier": "tap1",
          "type": "tap",
          "location": "start",
          "outcomes": [
            { "type": "dismiss", "cancel": true, "identifier": "dec.dismiss.true" }
          ]
        }
        """
        let tapOn = try decoder.decode(ThomasViewInfo.Pager.Gesture.self, from: Data(withOutcomes.utf8))
        guard case .tapGesture(let t1) = tapOn else {
            Issue.record("Expected tap")
            return
        }
        #expect(t1.outcomes?.count == 1)

        let legacy = """
        {
          "identifier": "tap2",
          "type": "tap",
          "location": "end",
          "behavior": {
            "behaviors": ["pager_previous"]
          }
        }
        """
        let tapOff = try decoder.decode(ThomasViewInfo.Pager.Gesture.self, from: Data(legacy.utf8))
        guard case .tapGesture(let t2) = tapOff else {
            Issue.record("Expected tap")
            return
        }
        #expect(t2.outcomes == nil)
        #expect(t2.behavior?.behaviors == [.pagerPrevious])
    }

    @Test
    func pagerHoldDecodesPressAndReleaseOutcomesIndependently() throws {
        let json = """
        {
          "type": "hold",
          "identifier": "hold1",
          "press_outcomes": [
            { "type": "pager_playback", "command": "pause", "identifier": "dec.hold.pause" }
          ],
          "release_outcomes": [
            { "type": "pager_playback", "command": "resume", "identifier": "dec.hold.resume" }
          ]
        }
        """
        let gesture = try decoder.decode(ThomasViewInfo.Pager.Gesture.self, from: Data(json.utf8))
        guard case .holdGesture(let hold) = gesture else {
            Issue.record("Expected hold")
            return
        }
        #expect(hold.pressOutcomes?.count == 1)
        #expect(hold.releaseOutcomes?.count == 1)
    }

    @Test
    func pagerHoldLegacyBehaviorsOnly() throws {
        let json = """
        {
          "type": "hold",
          "identifier": "hold2",
          "press_behavior": {
            "behaviors": ["pager_pause"]
          },
          "release_behavior": {
            "behaviors": ["pager_resume"]
          }
        }
        """
        let gesture = try decoder.decode(ThomasViewInfo.Pager.Gesture.self, from: Data(json.utf8))
        guard case .holdGesture(let hold) = gesture else {
            Issue.record("Expected hold")
            return
        }
        #expect(hold.pressOutcomes == nil)
        #expect(hold.releaseOutcomes == nil)
        #expect(hold.pressBehavior?.behaviors == [.pagerPause])
        #expect(hold.releaseBehavior?.behaviors == [.pagerResume])
    }
}
