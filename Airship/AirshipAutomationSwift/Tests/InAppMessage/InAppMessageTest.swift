/* Copyright Airship and Contributors */

import XCTest

@testable
import AirshipAutomationSwift
import AirshipCore

final class InAppMessageTest: XCTestCase {
    
    func testBanner() throws {
        let json = """
          {
             "source": "remote-data",
             "display" : {
                "allow_fullscreen_display" : true,
                "background_color" : "#ffffff",
                "body" : {
                   "alignment" : "center",
                   "color" : "#000000",
                   "font_family" : [
                      "sans-serif"
                   ],
                   "size" : 16,
                   "text" : "Big body"
                },
                "border_radius" : 5,
                "button_layout" : "stacked",
                "buttons" : [
                   {
                      "actions" : {},
                      "background_color" : "#63aff2",
                      "border_color" : "#63aff2",
                      "border_radius" : 2,
                      "id" : "d17a055c-ed67-4101-b65f-cd28b5904c84",
                      "label" : {
                         "color" : "#ffffff",
                         "font_family" : [
                            "sans-serif"
                         ],
                         "size" : 10,
                         "style" : [
                            "bold"
                         ],
                         "text" : "Touch it"
                      }
                   }
                ],
                "dismiss_button_color" : "#000000",
                "heading" : {
                   "alignment" : "center",
                   "color" : "#63aff2",
                   "font_family" : [
                      "sans-serif"
                   ],
                   "size" : 22,
                   "text" : "Boom"
                },
                "media" : {
                   "description" : "Image",
                   "type" : "image",
                   "url" : "some://image"
                },
                "template" : "media_left",
                "placement" : "top",
                "duration" : 100.0
             },
             "display_type" : "banner",
             "name" : "woot"
          }
        """

        let expected = InAppMessage(
            name: "woot",
            displayContent: .banner(
                .init(
                    heading: .init(
                        text: "Boom",
                        color: .init(hexColorString: "#63aff2"),
                        size: 22.0,
                        fontFamilies: ["sans-serif"],
                        alignment: .center
                    ),
                    body: .init(
                        text: "Big body",
                        color: .init(hexColorString: "#000000"),
                        size: 16.0,
                        fontFamilies: ["sans-serif"],
                        alignment: .center
                    ),
                    media: .init(
                        url: "some://image",
                        type: .image,
                        description: "Image"
                    ),
                    buttons: [
                        .init(
                            identifier: "d17a055c-ed67-4101-b65f-cd28b5904c84",
                            label: .init(
                                text: "Touch it",
                                color: .init(hexColorString: "#ffffff"),
                                size: 10,
                                fontFamilies: ["sans-serif"],
                                style: [.bold]
                            ),
                            actions: AirshipJSON.object([:]),
                            backgroundColor: .init(hexColorString: "#63aff2"),
                            borderColor: .init(hexColorString: "#63aff2"),
                            borderRadius: 2
                        )
                    ],
                    buttonLayoutType: .stacked,
                    template: .mediaLeft,
                    backgroundColor: .init(hexColorString: "#ffffff"),
                    dismissButtonColor: .init(hexColorString: "#000000"),
                    borderRadius: 5,
                    duration: 100.0,
                    placement: .top
                )
            ),
            source: .remoteData
        )

        try verify(json: json, expected: expected)
    }

    func testModal() throws {
        let json = """
          {
             "source": "app-defined",
             "display" : {
                "allow_fullscreen_display" : true,
                "background_color" : "#ffffff",
                "body" : {
                   "alignment" : "center",
                   "color" : "#000000",
                   "font_family" : [
                      "sans-serif"
                   ],
                   "size" : 16,
                   "text" : "Big body"
                },
                "border_radius" : 5,
                "button_layout" : "stacked",
                "buttons" : [
                   {
                      "actions" : {},
                      "background_color" : "#63aff2",
                      "border_color" : "#63aff2",
                      "border_radius" : 2,
                      "id" : "d17a055c-ed67-4101-b65f-cd28b5904c84",
                      "label" : {
                         "color" : "#ffffff",
                         "font_family" : [
                            "sans-serif"
                         ],
                         "size" : 10,
                         "style" : [
                            "bold"
                         ],
                         "text" : "Touch it"
                      }
                   }
                ],
                "dismiss_button_color" : "#000000",
                "heading" : {
                   "alignment" : "center",
                   "color" : "#63aff2",
                   "font_family" : [
                      "sans-serif"
                   ],
                   "size" : 22,
                   "text" : "Boom"
                },
                "media" : {
                   "description" : "Image",
                   "type" : "image",
                   "url" : "some://image"
                },
                "template" : "media_header_body",
             },
             "display_type" : "modal",
             "name" : "woot"
          }
        """

        let expected = InAppMessage(
            name: "woot",
            displayContent: .modal(
                .init(
                    heading: .init(
                        text: "Boom",
                        color: .init(hexColorString: "#63aff2"),
                        size: 22.0,
                        fontFamilies: ["sans-serif"],
                        alignment: .center
                    ),
                    body: .init(
                        text: "Big body",
                        color: .init(hexColorString: "#000000"),
                        size: 16.0,
                        fontFamilies: ["sans-serif"],
                        alignment: .center
                    ),
                    media: .init(
                        url: "some://image",
                        type: .image,
                        description: "Image"
                    ),
                    buttons: [
                        .init(
                            identifier: "d17a055c-ed67-4101-b65f-cd28b5904c84",
                            label: .init(
                                text: "Touch it",
                                color: .init(hexColorString: "#ffffff"),
                                size: 10,
                                fontFamilies: ["sans-serif"],
                                style: [.bold]
                            ),
                            actions: AirshipJSON.object([:]),
                            backgroundColor: .init(hexColorString: "#63aff2"),
                            borderColor: .init(hexColorString: "#63aff2"),
                            borderRadius: 2
                        )
                    ],
                    buttonLayoutType: .stacked,
                    template: .mediaHeaderBody,
                    dismissButtonColor: .init(hexColorString: "#000000"),
                    backgroundColor: .init(hexColorString: "#ffffff"),
                    borderRadius: 5,
                    allowFullscreenDisplay: true
                )
            ),
            source: .appDefined
        )

        try verify(json: json, expected: expected)
    }

    func testFullscreen() throws {
        let json = """
          {
             "source": "app-defined",
             "display" : {
                "background_color" : "#ffffff",
                "body" : {
                   "alignment" : "center",
                   "color" : "#000000",
                   "font_family" : [
                      "sans-serif"
                   ],
                   "size" : 16,
                   "text" : "Big body"
                },
                "button_layout" : "stacked",
                "buttons" : [
                   {
                      "actions" : {},
                      "background_color" : "#63aff2",
                      "border_color" : "#63aff2",
                      "border_radius" : 2,
                      "id" : "d17a055c-ed67-4101-b65f-cd28b5904c84",
                      "label" : {
                         "color" : "#ffffff",
                         "font_family" : [
                            "sans-serif"
                         ],
                         "size" : 10,
                         "style" : [
                            "bold"
                         ],
                         "text" : "Touch it"
                      }
                   }
                ],
                "dismiss_button_color" : "#000000",
                "heading" : {
                   "alignment" : "center",
                   "color" : "#63aff2",
                   "font_family" : [
                      "sans-serif"
                   ],
                   "size" : 22,
                   "text" : "Boom"
                },
                "media" : {
                   "description" : "Image",
                   "type" : "image",
                   "url" : "some://image"
                },
                "template" : "media_header_body",
             },
             "display_type" : "fullscreen",
             "name" : "woot"
          }
        """

        let expected = InAppMessage(
            name: "woot",
            displayContent: .fullscreen(
                .init(
                    heading: .init(
                        text: "Boom",
                        color: .init(hexColorString: "#63aff2"),
                        size: 22.0,
                        fontFamilies: ["sans-serif"],
                        alignment: .center
                    ),
                    body: .init(
                        text: "Big body",
                        color: .init(hexColorString: "#000000"),
                        size: 16.0,
                        fontFamilies: ["sans-serif"],
                        alignment: .center
                    ),
                    media: .init(
                        url: "some://image",
                        type: .image,
                        description: "Image"
                    ),
                    buttons: [
                        .init(
                            identifier: "d17a055c-ed67-4101-b65f-cd28b5904c84",
                            label: .init(
                                text: "Touch it",
                                color: .init(hexColorString: "#ffffff"),
                                size: 10,
                                fontFamilies: ["sans-serif"],
                                style: [.bold]
                            ),
                            actions: AirshipJSON.object([:]),
                            backgroundColor: .init(hexColorString: "#63aff2"),
                            borderColor: .init(hexColorString: "#63aff2"),
                            borderRadius: 2
                        )
                    ],
                    buttonLayoutType: .stacked,
                    template: .mediaHeaderBody,
                    dismissButtonColor: .init(hexColorString: "#000000"),
                    backgroundColor: .init(hexColorString: "#ffffff")
                )
            ),
            source: .appDefined
        )

        try verify(json: json, expected: expected)
    }

    func testHTML() throws {
        let json = """
         {
             "display" : {
                "allow_fullscreen_display" : false,
                "background_color" : "#00000000",
                "border_radius" : 5,
                "dismiss_button_color" : "#000000",
                "url" : "some://url"
             },
             "display_type" : "html",
             "name" : "Thanks page"
         }
        """

        let expected = InAppMessage(
            name: "Thanks page",
            displayContent: .html(
                .init(
                    url: "some://url",
                    dismissButtonColor: .init(hexColorString: "#000000"),
                    backgroundColor: .init(hexColorString: "#00000000"),
                    borderRadius: 5.0,
                    allowFullscreen: false
                )
            ),
            source: nil
        )

        try verify(json: json, expected: expected)
    }

    func testCustom() throws {
        let json = """
          {
             "source": "app-defined",
             "display" : {
                "cool": "story"
             },
             "display_type" : "custom",
             "name" : "woot"
          }
        """

        let expected = InAppMessage(
            name: "woot",
            displayContent: .custom(
                AirshipJSON.object(["cool": .string("story")])
            ),
            source: .appDefined
        )

        try verify(json: json, expected: expected)
    }

    func testAirshipLayout() throws {
        let json = """
          {
             "source": "remote-data",
             "display" : {
                "complicated": "payload"
             },
             "display_type" : "layout",
             "name" : "Airship layout"
          }
        """

        let expected = InAppMessage(
            name: "Airship layout",
            displayContent: .airshipLayout(
                AirshipJSON.object(["complicated": .string("payload")])
            ),
            source: .remoteData
        )

        try verify(json: json, expected: expected)
    }

    func verify(json: String, expected: InAppMessage) throws {
        let decoder = JSONDecoder()
        let encoder = JSONEncoder()

        let fromJSON = try decoder.decode(InAppMessage.self, from: json.data(using: .utf8)!)
        XCTAssertEqual(fromJSON, expected)

        let roundTrip = try decoder.decode(InAppMessage.self, from: try encoder.encode(fromJSON))
        XCTAssertEqual(roundTrip, fromJSON)
    }
}
