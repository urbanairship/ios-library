/* Copyright Airship and Contributors */

import Foundation
import Testing

@testable import AirshipBasement
@testable @_spi(AirshipInternal) import AirshipSceneRenderer

@Suite(.timeLimit(.minutes(1)))
struct LayoutModelsTest {

    @Test
    func size() throws {
        let json = """
            {
                "presentation": {
                    "type": "modal",
                    "default_placement": {
                        "size": {
                            "width": "60%",
                            "height": "60%"
                        },
                        "placement": {
                            "horizontal": "center",
                            "vertical": "center"
                        }
                    }
                },
                "version": 1,
                "view": {
                  "type": "container",
                  "items": [
                    {
                      "position": {
                        "horizontal": "center",
                        "vertical": "center"
                      },
                      "size": {
                        "height": "auto",
                        "width": "75%"
                      },
                      "view": {
                        "type": "empty_view"
                      }
                    }
                  ]
                }
            }
            """

        let layout = try decode(json.data(using: .utf8)!)
        guard case .container(let container) = layout.view else {
            Issue.record("Expected container view")
            return
        }

        let size = container.properties.items.first?.size

        #expect(ThomasSizeConstraint.auto == size?.height)
        #expect(ThomasSizeConstraint.percent(75) == size?.width)
    }

    @Test
    func complexExample() throws {
        let json = """
            {
                "presentation": {
                    "type": "modal",
                    "default_placement": {
                        "size": {
                            "width": "60%",
                            "height": "60%"
                        },
                        "placement": {
                            "horizontal": "center",
                            "vertical": "center"
                        }
                    }
                },
                "version": 1,
                "view": {
                  "type": "container",
                  "items": [
                    {
                      "position": {
                        "horizontal": "center",
                        "vertical": "center"
                      },
                      "size": {
                        "height": "100%",
                        "width": "100%"
                      },
                      "view": {
                        "type": "linear_layout",
                        "direction": "vertical",
                        "items": [
                          {
                            "position": {
                              "horizontal": "center",
                              "vertical": "center"
                            },
                            "margin": {
                              "top": 0,
                              "bottom": 0,
                              "start": 16,
                              "end": 16
                            },
                            "size": {
                              "width": "100%",
                              "height": "auto"
                            },
                            "view": {
                              "type": "label_button",
                              "identifier": "BUTTON",
                              "background_color": { "default": { "hex": "#FF00FF" } },
                              "label": {
                                "type": "label",
                                "text_appearance": {
                                    "font_size": 24,
                                    "alignment": "center",
                                    "text_styles": [
                                      "bold",
                                      "italic",
                                      "underlined"
                                    ],
                                    "font_families": [
                                      "permanent_marker"
                                    ],
                                    "color": { "default": { "hex": "#FF00FF"} }
                                },
                                "text": "NO"
                              }
                            }
                          }
                        ]
                      }
                    }
                  ]
                }
            }
            """

        _ = try decode(json.data(using: .utf8)!)
    }

    private func decode(_ data: Data) throws -> AirshipLayout {
        try JSONDecoder().decode(AirshipLayout.self, from: data)
    }
}
