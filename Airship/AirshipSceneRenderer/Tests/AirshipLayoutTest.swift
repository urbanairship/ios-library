/* Copyright Airship and Contributors */

import Foundation
import Testing

@testable import AirshipBasement
@testable @_spi(AirshipInternal) import AirshipSceneRenderer

@Suite("AirshipLayout JSON parsing")
struct AirshipLayoutTest {

    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()

    @Test
    func decodesMinimalModalLayout() throws {
        let json = """
        {
          "version": 1,
          "presentation": {
            "type": "modal",
            "default_placement": {
              "size": { "width": "60%", "height": "60%" },
              "placement": { "horizontal": "center", "vertical": "center" }
            }
          },
          "view": { "type": "empty_view" }
        }
        """
        let layout = try decode(json)

        #expect(layout.version == 1)
        #expect(layout.validate())
        switch layout.presentation {
        case .modal:
            break
        default:
            Issue.record("Expected modal presentation")
        }
        switch layout.view {
        case .emptyView:
            break
        default:
            Issue.record("Expected empty_view")
        }
        #expect(layout.options == nil)
    }

    @Test
    func decodesVersion2() throws {
        let json = """
        {
          "version": 2,
          "presentation": {
            "type": "modal",
            "default_placement": {
              "size": { "width": "100%", "height": "100%" }
            }
          },
          "view": { "type": "empty_view" }
        }
        """
        let layout = try decode(json)
        #expect(layout.version == 2)
        #expect(layout.validate())
    }

    @Test
    func embeddedPresentationSetsIsEmbedded() throws {
        let json = """
        {
          "version": 1,
          "presentation": {
            "type": "embedded",
            "embedded_id": "slot_a",
            "default_placement": {
              "size": { "width": "100%", "height": "100%" }
            }
          },
          "view": { "type": "empty_view" }
        }
        """
        let layout = try decode(json)
        #expect(layout.isEmbedded)
        switch layout.presentation {
        case .embedded(let embedded):
            #expect(embedded.embeddedID == "slot_a")
        default:
            Issue.record("Expected embedded presentation")
        }
    }

    @Test
    func modalPresentationIsNotEmbedded() throws {
        let json = """
        {
          "version": 1,
          "presentation": {
            "type": "modal",
            "default_placement": {
              "size": { "width": "100%", "height": "100%" }
            }
          },
          "view": { "type": "empty_view" }
        }
        """
        let layout = try decode(json)
        #expect(!layout.isEmbedded)
    }

    @Test
    func decodesStateRestorationOptions() throws {
        let json = """
        {
          "version": 1,
          "presentation": {
            "type": "modal",
            "default_placement": {
              "size": { "width": "100%", "height": "100%" }
            }
          },
          "options": {
            "state_restoration": {
              "scope": "instance",
              "restore_id": "form-v1"
            }
          },
          "view": { "type": "empty_view" }
        }
        """
        let layout = try decode(json)
        #expect(layout.options?.stateRestoration?.scope == .instance)
        #expect(layout.options?.stateRestoration?.restoreID == "form-v1")
    }

    @Test
    func omittedOptionsDecodesAsNil() throws {
        let json = """
        {
          "version": 1,
          "presentation": {
            "type": "modal",
            "default_placement": {
              "size": { "width": "100%", "height": "100%" }
            }
          },
          "view": { "type": "empty_view" }
        }
        """
        let layout = try decode(json)
        #expect(layout.options == nil)
    }

    @Test
    func missingViewThrowsKeyNotFound() {
        let json = """
        {
          "version": 1,
          "presentation": {
            "type": "modal",
            "default_placement": {
              "size": { "width": "100%", "height": "100%" }
            }
          }
        }
        """
        let result = Result { try decode(json) }
        guard case .failure(let error) = result else {
            Issue.record("Expected decode to fail")
            return
        }
        guard case DecodingError.keyNotFound(let key, _) = error else {
            Issue.record("Expected keyNotFound, got \(error)")
            return
        }
        #expect(key.stringValue == "view")
    }

    @Test
    func roundTripMatchesOriginalJSON() throws {
        let json = """
        {
          "version": 1,
          "presentation": {
            "type": "embedded",
            "embedded_id": "home_banner",
            "default_placement": {
              "size": { "width": "50%", "height": "50%" },
              "margin": { "top": 16, "bottom": 16, "start": 16, "end": 16 }
            }
          },
          "options": {
            "state_restoration": {
              "scope": "instance",
              "restore_id": "rt-id"
            }
          },
          "view": { "type": "empty_view" }
        }
        """
        try decodeEncodeCompare(source: json, type: AirshipLayout.self)
    }

    @Test
    func stackImageButtonRoundTripMatchesOriginalJSON() throws {
        // Pins the stack_image_button `type` field surviving re-encoding
        let json = """
        {
          "version": 1,
          "presentation": {
            "type": "banner",
            "default_placement": {
              "size": { "width": "100%", "height": "auto" },
              "position": { "horizontal": "center", "vertical": "top" }
            }
          },
          "view": {
            "type": "stack_image_button",
            "identifier": "dismiss_button",
            "items": [
              {
                "type": "icon",
                "icon": {
                  "type": "icon",
                  "icon": "close",
                  "scale": 0.4,
                  "color": {
                    "default": { "type": "hex", "hex": "#000000", "alpha": 1 }
                  }
                }
              },
              {
                "type": "image_url",
                "url": "https://example.com/button.png",
                "media_fit": "center_inside"
              }
            ]
          }
        }
        """
        try decodeEncodeCompare(source: json, type: AirshipLayout.self)
    }

    @Test
    func decodesContentDescription() throws {
        let json = """
        {
          "version": 1,
          "presentation": {
            "type": "embedded",
            "embedded_id": "slot",
            "default_placement": { "size": { "width": "100%", "height": "auto" } }
          },
          "view": { "type": "empty_view" },
          "content_description": {
            "description": "Spring sale on cat trees and toys",
            "additional_context": [
              { "content": "Sale ends Friday", "priority": -1 },
              { "content": "Cat category" }
            ]
          }
        }
        """
        let layout = try decode(json)

        #expect(layout.contentDescription?.description == "Spring sale on cat trees and toys")
        #expect(layout.contentDescription?.additionalContext?.count == 2)
        #expect(layout.contentDescription?.additionalContext?.first?.content == "Sale ends Friday")
        #expect(layout.contentDescription?.additionalContext?.first?.priority == -1)
        // Priority is optional on the wire; the consumer defaults it to 0.
        #expect(layout.contentDescription?.additionalContext?.last?.priority == nil)
    }

    @Test
    func contentDescriptionIsOptional() throws {
        let json = """
        {
          "version": 1,
          "presentation": {
            "type": "embedded",
            "embedded_id": "slot",
            "default_placement": { "size": { "width": "100%", "height": "auto" } }
          },
          "view": { "type": "empty_view" }
        }
        """
        #expect(try decode(json).contentDescription == nil)
    }

    private func decode(_ json: String) throws -> AirshipLayout {
        guard let data = json.data(using: .utf8) else {
            struct Encoding: Error {}
            throw Encoding()
        }
        return try decoder.decode(AirshipLayout.self, from: data)
    }

    private func decodeEncodeCompare<T: Codable & Equatable>(source: String, type: T.Type) throws {
        let decoded = try decoder.decode(type, from: source.data(using: .utf8)!)
        let encoded = try encoder.encode(decoded)
        let restored = try decoder.decode(type, from: encoded)

        #expect(restored == decoded)

        let inputJson = try JSONSerialization.jsonObject(with: source.data(using: .utf8)!) as! [String: Any]
        let encodedJson = try JSONSerialization.jsonObject(with: encoded) as! [String: Any]
        
        let input = try AirshipJSON.wrap(inputJson)
        let output = try AirshipJSON.wrap(encodedJson)

        #expect(input == output)
    }
}
