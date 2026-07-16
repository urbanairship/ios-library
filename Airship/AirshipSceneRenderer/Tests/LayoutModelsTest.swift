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

    @Test
    func stackImageView() throws {
        let json = """
            {
                "presentation": {
                    "type": "banner",
                    "default_placement": {
                        "size": {
                            "width": "100%",
                            "height": "auto"
                        },
                        "position": {
                            "horizontal": "center",
                            "vertical": "bottom"
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
                        "vertical": "top"
                      },
                      "size": {
                        "height": 4,
                        "width": 36
                      },
                      "view": {
                        "type": "stack_image_view",
                        "identifier": "nub",
                        "content_description": "Nub",
                        "items": [
                          {
                            "type": "shape",
                            "shape": {
                              "type": "rectangle",
                              "color": { "default": { "hex": "#000000", "alpha": 0.42 } },
                              "border": { "radius": 2 }
                            }
                          },
                          {
                            "type": "image_url",
                            "url": "https://example.com/nub.png",
                            "media_fit": "center_inside"
                          }
                        ]
                      }
                    }
                  ]
                }
            }
            """

        let layout = try decode(json.data(using: .utf8)!)
        guard
            case .container(let container) = layout.view,
            case .stackImageView(let stackImageView) = container.properties.items.first?.view
        else {
            Issue.record("Expected container with a stack_image_view item")
            return
        }

        #expect(stackImageView.properties.identifier == "nub")
        #expect(stackImageView.properties.items.count == 2)
        #expect(stackImageView.accessible.contentDescription == "Nub")

        // image_url items should be prefetched
        #expect(layout.urlInfos == [.image(url: "https://example.com/nub.png")])

        // Round trip
        let encoded = try JSONEncoder().encode(layout)
        let restored = try JSONDecoder().decode(AirshipLayout.self, from: encoded)
        #expect(restored == layout)
    }

    private func decode(_ data: Data) throws -> AirshipLayout {
        try JSONDecoder().decode(AirshipLayout.self, from: data)
    }
}
