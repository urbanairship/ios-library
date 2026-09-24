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
    func backgroundsOnContainer() throws {
        let json = """
            {
                "presentation": {
                    "type": "modal",
                    "default_placement": {
                        "size": { "width": "80%", "height": "auto" },
                        "placement": { "horizontal": "center", "vertical": "center" }
                    }
                },
                "version": 1,
                "view": {
                    "type": "container",
                    "items": [],
                    "backgrounds": [
                        {
                            "type": "color",
                            "color": { "default": { "hex": "#0B1B33", "alpha": 1 } }
                        },
                        {
                            "type": "gradient",
                            "gradient": {
                                "style": "linear",
                                "angle": 180,
                                "stops": [
                                    { "color": { "default": { "hex": "#000000", "alpha": 0 } }, "position": 0 },
                                    { "color": { "default": { "hex": "#000000", "alpha": 0.6 } }, "position": 1 }
                                ]
                            },
                            "blend_mode": "multiply"
                        },
                        {
                            "type": "media",
                            "media_type": "image",
                            "url": "https://example.com/hero.jpg",
                            "media_fit": "fit_crop",
                            "opacity": 0.9
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

        let backgrounds = container.properties.backgrounds
        #expect(backgrounds?.count == 3)

        guard case .color(let colorLayer) = backgrounds?[0] else {
            Issue.record("Expected a color background")
            return
        }
        #expect(colorLayer.blendMode == nil)

        guard case .gradient(let gradientLayer) = backgrounds?[1] else {
            Issue.record("Expected a gradient background")
            return
        }
        #expect(gradientLayer.gradient.style == .linear)
        #expect(gradientLayer.gradient.stops.count == 2)
        #expect(gradientLayer.blendMode == .multiply)

        guard case .media(let mediaLayer) = backgrounds?[2] else {
            Issue.record("Expected a media background")
            return
        }
        #expect(mediaLayer.mediaFit == .fitCrop)
        #expect(mediaLayer.opacity == 0.9)

        // Round trip
        let encoded = try JSONEncoder().encode(layout)
        let restored = try JSONDecoder().decode(AirshipLayout.self, from: encoded)
        #expect(restored == layout)
    }

    @Test
    func parallaxOnlyOnScrollLayoutAndPager() throws {
        let json = """
            {
                "presentation": {
                    "type": "modal",
                    "default_placement": {
                        "size": { "width": "80%", "height": "80%" },
                        "placement": { "horizontal": "center", "vertical": "center" }
                    }
                },
                "version": 1,
                "view": {
                    "type": "scroll_layout",
                    "direction": "vertical",
                    "view": { "type": "empty_view" },
                    "backgrounds": [
                        {
                            "type": "media",
                            "media_type": "image",
                            "url": "https://example.com/hero.jpg",
                            "media_fit": "fit_crop",
                            "parallax": { "factor": 0.4 }
                        },
                        {
                            "type": "color",
                            "color": { "default": { "hex": "#000000", "alpha": 0.5 } }
                        }
                    ]
                }
            }
            """

        let layout = try decode(json.data(using: .utf8)!)
        guard case .scrollLayout(let scrollLayout) = layout.view else {
            Issue.record("Expected scroll_layout view")
            return
        }

        let backgrounds = scrollLayout.properties.backgrounds
        #expect(backgrounds?.count == 2)
        #expect(backgrounds?[0].parallax == ThomasParallax(factor: 0.4))
        // A layer that leaves parallax out (e.g. a static color) simply has none.
        #expect(backgrounds?[1].parallax == nil)

        guard case .media(let mediaLayer) = backgrounds?[0].background else {
            Issue.record("Expected a media background")
            return
        }
        #expect(mediaLayer.mediaFit == .fitCrop)

        // `Container`'s `backgrounds` is `[ThomasBackground]?`, which has no `parallax`
        // case at all -- putting one there is a compile error, not a decode failure,
        // so there is nothing to exercise here at runtime.

        // Round trip
        let encoded = try JSONEncoder().encode(layout)
        let restored = try JSONDecoder().decode(AirshipLayout.self, from: encoded)
        #expect(restored == layout)
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

    @Test
    func backgroundMediaIsPrefetched() throws {
        let json = """
            {
                "presentation": {
                    "type": "modal",
                    "default_placement": {
                        "size": { "width": "80%", "height": "80%" },
                        "placement": { "horizontal": "center", "vertical": "center" }
                    }
                },
                "version": 1,
                "view": {
                    "type": "container",
                    "items": [],
                    "backgrounds": [
                        {
                            "type": "media",
                            "media_type": "image",
                            "url": "https://example.com/hero.jpg",
                            "media_fit": "fit_crop"
                        },
                        {
                            "type": "color",
                            "color": { "default": { "hex": "#000000", "alpha": 0.5 } }
                        }
                    ]
                }
            }
            """

        let layout = try decode(json.data(using: .utf8)!)
        #expect(layout.urlInfos == [.image(url: "https://example.com/hero.jpg")])
    }

    @Test
    func backgroundImageOverrideIsPrefetched() throws {
        let json = """
            {
                "presentation": {
                    "type": "modal",
                    "default_placement": {
                        "size": { "width": "80%", "height": "80%" },
                        "placement": { "horizontal": "center", "vertical": "center" }
                    }
                },
                "version": 1,
                "view": {
                    "type": "container",
                    "items": [],
                    "backgrounds": [
                        {
                            "type": "media",
                            "media_type": "image",
                            "url": "https://example.com/a.jpg",
                            "media_fit": "fit_crop",
                            "view_overrides": {
                                "url": [
                                    {
                                        "when_state_matches": { "scope": ["backdrop"], "value": { "equals": "b" } },
                                        "value": "https://example.com/b.jpg"
                                    }
                                ]
                            }
                        }
                    ]
                }
            }
            """

        let layout = try decode(json.data(using: .utf8)!)
        #expect(layout.urlInfos == [
            .image(url: "https://example.com/a.jpg"),
            .image(url: "https://example.com/b.jpg")
        ])
    }

    @Test
    func pagerBackgroundVideoIsPrefetched() throws {
        let json = """
            {
                "presentation": {
                    "type": "modal",
                    "default_placement": {
                        "size": { "width": "80%", "height": "80%" },
                        "placement": { "horizontal": "center", "vertical": "center" }
                    }
                },
                "version": 1,
                "view": {
                    "type": "pager_controller",
                    "identifier": "pager",
                    "view": {
                        "type": "pager",
                        "items": [],
                        "backgrounds": [
                            {
                                "type": "media",
                                "media_type": "video",
                                "url": "https://example.com/loop.mp4",
                                "media_fit": "fit_crop",
                                "parallax": { "factor": 0.3 }
                            }
                        ]
                    }
                }
            }
            """

        let layout = try decode(json.data(using: .utf8)!)
        #expect(layout.urlInfos == [.video(url: "https://example.com/loop.mp4")])
    }

    @Test
    func backgroundVideoTakesTouchesOnlyWithControls() throws {
        func layer(_ video: String) throws -> ThomasBackground {
            try JSONDecoder().decode(ThomasBackground.self, from: Data("""
                {
                    "type": "media",
                    "media_type": "video",
                    "url": "https://example.com/loop.mp4",
                    "media_fit": "fit_crop"
                    \(video)
                }
                """.utf8))
        }

        #expect(try layer("").acceptsTouches == false)

        let shown = try layer(#", "video": { "show_controls": true, "autoplay": true }"#)
        guard case .media(.video(let shownMedia)) = shown else {
            Issue.record("Expected a video media background")
            return
        }
        #expect(shownMedia.playerInfo.properties.video?.showControls == true)
        #expect(shownMedia.playerInfo.properties.video?.autoplay == true)
        #expect(shownMedia.playerInfo.properties.url == "https://example.com/loop.mp4")
        #expect(shown.acceptsTouches == true)
    }

    private func decode(_ data: Data) throws -> AirshipLayout {
        try JSONDecoder().decode(AirshipLayout.self, from: data)
    }
}
