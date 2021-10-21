/* Copyright Airship and Contributors */

import XCTest
@testable
import AirshipCore

class LayoutModelsTest: XCTestCase {

    func testSize() throws {
        let json = """
        {
            "layout": {
              "type": "container",
              "items": [
                {
                  "position": {
                    "horizontal": "center",
                    "vertical": "center"
                  },
                  "size": {
                    "height": "auto",
                    "width": "75%",
                    "min_width": 50,
                    "min_height": 100
                  },
                  "view": {
                    "type": "view"
                  }
                }
              ]
            }
        }
        """
        
        let layout = try! LayoutDecoder.decode(json.data(using: .utf8)!)
        let container = layout.layout as! ContainerModel
        let size = container.items.first?.size
            
        XCTAssertEqual(SizeConstraint.auto, size?.height)
        XCTAssertEqual(SizeConstraint.percent(75), size?.width)
        XCTAssertEqual(SizeConstraint.points(50), size?.minWidth)
        XCTAssertEqual(SizeConstraint.points(100), size?.minHeight)
    }
    
    func testComplexExample() throws {
        let json = """
        {
          "layout": {
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
                        "weight": 0,
                        "view": {
                          "type": "button",
                          "identifier": "BUTTON",
                          "color": { "hex": "#FF00FF" },
                          "label": {
                            "type": "label",
                            "font_size": 24,
                            "alignment": "center",
                            "text_styles": [
                              "bold",
                              "italic",
                              "underline"
                            ],
                            "font_families": [
                              "permanent_marker"
                            ],
                            "color": { "hex": "#FF00FF" },
                            "text": "NO"
                          }
                        }
                      },
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
                        "weight": 0,
                        "view": {
                          "type": "button",
                          "identifier": "BUTTON",
                          "color": { "hex": "#FF00FF" },
                          "label": {
                            "type": "label",
                            "font_size": 24,
                            "alignment": "center",
                            "text_Styles": [
                              "bold",
                              "italic",
                              "underline"
                            ],
                            "font_families": [
                              "permanent_marker"
                            ],
                            "color": { "hex": "#FF00FF" },
                            "text": "YES"
                          }
                        }
                      }
                    ]
                  }
                },
                {
                  "position": {
                    "horizontal": "end",
                    "vertical": "top"
                  },
                  "size": {
                    "width": 48,
                    "height": 48
                  },
                  "view": {
                    "type": "image_button",
                    "url": "https://testing-library.com/img/octopus-64x64.png",
                    "identifier": "myid"
                  }
                }
              ]
            }
        }
        """
        
        let layout = try LayoutDecoder.decode(json.data(using: .utf8)!)
        XCTAssertNotNil(layout)
    }

}
