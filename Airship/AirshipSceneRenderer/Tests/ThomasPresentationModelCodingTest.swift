/* Copyright Airship and Contributors */

import Foundation
import Testing

@testable import AirshipBasement
@testable @_spi(AirshipInternal) import AirshipSceneRenderer

@Suite(.timeLimit(.minutes(1)))
struct ThomasPresentationModelCodingTest {

    private let simpleContentViewJson = """
    {
       "type":"label",
       "text":"Sup Buddy",
       "text_appearance":{
          "font_size":14,
          "color":{
             "type": "hex",
             "default":{
                "hex":"#333333"
             }
          },
          "alignment":"start",
          "styles":[
             "italic"
          ],
          "font_families":[
             "permanent_marker",
             "casual"
          ]
       }
    }
    """

    @Test
    func bannerPresentationModelCodable() throws {
        let json = """
        {
          "type": "banner",
          "placement_selectors": [
            {
              "orientation": "landscape",
              "placement": {
                "size": {
                  "width": "50%",
                  "height": 500
                },
                "border": {
                  "radius": 20
                },
                "position": {
                  "horizontal": "center",
                  "vertical": "bottom"
                }
              }
            }
          ],
          "default_placement": {
            "size": {
              "width": "100%",
              "height": 500
            },
            "position": {
              "horizontal": "center",
              "vertical": "bottom"
            }
          }
        }
        """
        try decodeEncodeCompare(source: json, type: ThomasPresentationInfo.self)
    }

    @Test
    func modalPresentationModelCodable() throws {
        let json = """
        {
          "default_placement": {
            "size": {
              "min_width": "100%",
              "min_height": "100%",
              "max_height": "100%",
              "height": "100%",
              "width": "100%",
              "max_width": "100%"
            },
            "animation":{
              "type": "slide",
              "animate_in_seconds": 0.3,
              "animate_out_seconds": 0.3,
              "origin":{
                "horizontal": "center",
                "vertical": "bottom"
              }
            },
            "device": {
              "lock_orientation": "portrait"
            },
            "shade_color": {
              "default": {
                "type": "hex",
                "alpha": 0.2,
                "hex": "#000000"
              }
            },
            "ignore_safe_area": false,
            "position": {
              "horizontal": "center",
              "vertical": "top"
            }
          },
          "type": "modal",
          "dismiss_on_touch_outside": false
        }
        """
        try decodeEncodeCompare(source: json, type: ThomasPresentationInfo.self)
    }

    @Test
    func embeddedPresentationModelCodable() throws {
        let json = """
        {
          "type": "embedded",
          "embedded_id": "home_banner",
          "default_placement": {
            "size": {
              "width": "100%",
              "height": "100%"
            },
            "margin": {
              "top": 16,
              "bottom": 16,
              "start": 16,
              "end": 16
            }
          }
        }
        """
        try decodeEncodeCompare(source: json, type: ThomasPresentationInfo.Embedded.self)
    }

    @Test
    func presentationModelCodable() throws {
        let json = """
        {
          "default_placement": {
            "size": {
              "min_width": "100%",
              "min_height": "100%",
              "max_height": "100%",
              "height": "100%",
              "width": "100%",
              "max_width": "100%"
            },
            "device": {
              "lock_orientation": "portrait"
            },
            "shade_color": {
              "default": {
                "type": "hex",
                "alpha": 0.2,
                "hex": "#000000"
              }
            },
            "ignore_safe_area": false,
            "position": {
              "horizontal": "center",
              "vertical": "top"
            }
          },
          "type": "modal",
          "dismiss_on_touch_outside": false
        }
        """
        try decodeEncodeCompare(source: json, type: ThomasPresentationInfo.self)
    }

    @Test
    func airshipLayoutCodable() throws {
        let json = """
        {
          "version": 1,
          "presentation": {
            "type": "embedded",
            "embedded_id": "home_banner",
            "default_placement": {
              "size": {
                "width": "50%",
                "height": "50%"
              },
              "margin": {
                "top": 16,
                "bottom": 16,
                "start": 16,
                "end": 16
              }
            }
          },
          "view": {
            "type": "container",
            "border": {
              "stroke_color": {
                "default": {
                  "type": "hex",
                  "hex": "#FF0D49",
                  "alpha": 1
                }
              },
              "stroke_width": 2
            },
            "background_color": {
              "selectors": [
                {
                  "platform": "ios",
                  "dark_mode": false,
                  "color": {
                    "type": "hex",
                    "hex": "#FFFFFF",
                    "alpha": 1
                  }
                },
                {
                  "platform": "ios",
                  "dark_mode": true,
                  "color": {
                    "type": "hex",
                    "hex": "#000000",
                    "alpha": 1
                  }
                }
              ],
              "default": {
                "type": "hex",
                "hex": "#FF00FF",
                "alpha": 1
              }
            },
            "items": [
              {
                "position": {
                  "horizontal": "center",
                  "vertical": "center"
                },
                "size": {
                  "width": "100%",
                  "height": "auto"
                },
                "view": {
                  "type": "label",
                  "text": "50% x 50%.",
                  "text_appearance": {
                    "font_size": 14,
                    "color": {
                      "selectors": [
                        {
                          "platform": "ios",
                          "dark_mode": true,
                          "color": {
                            "type": "hex",
                            "hex": "#FFFFFF",
                            "alpha": 1
                          }
                        },
                        {
                          "platform": "ios",
                          "dark_mode": false,
                          "color": {
                            "type": "hex",
                            "hex": "#000000",
                            "alpha": 1
                          }
                        }
                      ],
                      "default": {
                        "type": "hex",
                        "hex": "#FF00FF",
                        "alpha": 1
                      }
                    }
                  }
                }
              }
            ]
          }
        }
        """
        try decodeEncodeCompare(source: json, type: AirshipLayout.self)
    }

    @Test
    func modalPresentationWithKeyboardAvoidanceSafeArea() throws {
        let json = """
        {
          "default_placement": {
            "size": {
              "width": "100%",
              "height": "100%"
            }
          },
          "type": "modal",
          "ios": {
            "keyboard_avoidance": "safe_area"
          }
        }
        """
        try decodeEncodeCompare(source: json, type: ThomasPresentationInfo.self)

        let decoded = try JSONDecoder().decode(ThomasPresentationInfo.self, from: json.data(using: .utf8)!)
        if case .modal(let modal) = decoded {
            #expect(modal.ios?.keyboardAvoidance == .safeArea)
        } else {
            Issue.record("Expected modal presentation")
        }
    }

    private func decodeEncodeCompare<T: Codable & Equatable>(source: String, type: T.Type) throws {
        let decoder = JSONDecoder()
        let encoder = JSONEncoder()

        let decoded = try decoder.decode(type, from: source.data(using: .utf8)!)
        let json = try encoder.encode(decoded)
        let restored = try decoder.decode(type, from: json)

        #expect(restored == decoded)

        let inputJson = try JSONSerialization.jsonObject(with: source.data(using: .utf8)!) as! [String: Any]
        let encodedJson = try JSONSerialization.jsonObject(with: json) as! [String: Any]

        let input = try AirshipJSON.wrap(inputJson)
        let output = try AirshipJSON.wrap(encodedJson)

        #expect(input == output)
    }
}
