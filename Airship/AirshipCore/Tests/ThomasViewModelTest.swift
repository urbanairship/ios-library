/* Copyright Airship and Contributors */

import XCTest

@testable import AirshipCore

final class ThomasViewModelTest: XCTestCase {

    func testShapeModelCoding() throws {
        let rectangle = """
        {
          "type": "rectangle",
          "scale": 0.5,
          "aspect_ratio": 1,
          "color": {
            "default": {
              "type": "hex",
              "hex": "#66FF66",
              "alpha": 1
            }
          },
          "border": {
            "stroke_width": 2,
            "radius": 5,
            "stroke_color": {
              "default": {
                "type": "hex",
                "hex": "#333333",
                "alpha": 1
              }
            }
          }
        }
        """

        try decodeEncodeCompare(source: rectangle, type: ThomasShapeInfo.self)

        let ellipse = """
        {
          "border": {
            "radius": 2,
            "stroke_color": {
              "default": {
                "type": "hex",
                "alpha": 1,
                "hex": "#000000",
              }
            },
            "stroke_width": 1
          },
          "color": {
            "default": {
              "type": "hex",
              "alpha": 1,
              "hex": "#DDDDDD",
            }
          },
          "scale": 1,
          "type": "ellipse"
        }
        """

        try decodeEncodeCompare(source: ellipse, type: ThomasShapeInfo.self)
    }


    func testLabelInfo() throws {
        let json = """
        {
          "type": "label",
          "text": "You'll love these",
          "content_description": "Love it",
          "border": {
            "radius": 15,
            "stroke_width": 1,
            "stroke_color": {
              "default": {
                "type": "hex",
                "hex": "#FFFFFF",
                "alpha": 0
              }
            }
          },
          "text_appearance": {
            "font_size": 44,
            "color": {
              "default": {
                "type": "hex",
                "hex": "#000000",
                "alpha": 1
              }
            },
            "alignment": "start",
            "styles": [],
            "font_families": ["sans-serif"]
          },
          "view_overrides": {
            "background_color": [{
            }],
            "text": [{
              "when_state_matches": {
                "scope": ["some-id:error"],
                "value": {
                  "equals": true
                }
              },
              "value": "neat"
            }]
          }
        }
        """
        try decodeEncodeCompare(source: json, type: ThomasViewInfo.Label.self)


    }
    func testSizeCoding() throws {
        let autoPercent = "{\"width\": \"auto\", \"height\":\"101%\"}"
        let percentToPoints = "{\"width\":\"101%\", \"height\":45}"

        try decodeEncodeCompare(source: autoPercent, type: ThomasSize.self)
        try decodeEncodeCompare(source: percentToPoints, type: ThomasSize.self)
    }

    func testVisibilityInfoCoding() throws {
        let json = """
        {
          "default": false,
          "invert_when_state_matches": {
            "or": [
              {
                "key": "neat",
                "value": {
                  "equals": "dissatisfied"
                }
              },
              {
                "key": "neat",
                "value": {
                  "equals": "very_dissatisfied"
                }
              }
            ]
          }
        }
        """

        try decodeEncodeCompare(source: json, type: ThomasVisibilityInfo.self)
    }

    func testEventHandlerCodable() throws {
        let json = """
        {
          "type": "form_input",
          "state_actions": [
            {
              "type": "clear",
            },
            {
              "type": "set_form_value",
              "key": "neat"
            },
            {
              "type": "set",
              "key": "label_tapped",
              "value": true
            }
          ]
        }
        """

        try decodeEncodeCompare(source: json, type: ThomasEventHandler.self)
    }

    func testWebViewModelCodable() throws {
        let json = """
        {
          "type": "web_view",
          "url": "https://example.com",
          "event_handlers": [
            {
              "type": "tap",
              "state_actions": [
                {
                  "type": "set",
                  "key": "web_view_tapped",
                  "value": true
                }
              ]
            }
          ]
        }
        """

        try decodeEncodeCompare(source: json, type: ThomasViewInfo.self)
    }

    func testCustomViewModelCodable() throws {
        let json = """
        {
          "type": "custom_view",
          "name": "ad_custom_view",
          "properties": {
            "ad_type": "fashion"
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
          }
        }
        """

        try decodeEncodeCompare(source: json, type: ThomasViewInfo.self)
    }

    func testMediaViewModelCodable() throws {
        let image = """
        {
          "media_fit": "center_inside",
          "media_type": "image",
          "type": "media",
          "url": "https://example.com"
        }
        """

        try decodeEncodeCompare(source: image, type: ThomasViewInfo.self)

        let video = """
        {
          "type": "media",
          "media_type": "video",
          "video": {
            "aspect_ratio": 0.56,
            "show_controls": true,
            "autoplay": true,
            "muted": true,
            "loop": true
          },
          "media_fit": "center_inside",
          "url": "https://hangar-dl.urbanairshi.com"
        }
        """

        try decodeEncodeCompare(source: video, type: ThomasViewInfo.self)

        let youtube = """
        {
          "media_fit": "center_inside",
          "media_type": "youtube",
          "type": "media",
          "url": "https://www.youtube.com/embed/xUOQZeN8A7o",
          "video": {
            "aspect_ratio": 1.77777777777778,
            "autoplay": false,
            "loop": true,
            "muted": true,
            "show_controls": true
          }
        }
        """

        try decodeEncodeCompare(source: youtube, type: ThomasViewInfo.self)
    }

    func testLabelModelCodable() throws {
        let json = """
        {
          "type": "label",
          "text": "Sup Buddy",
          "text_appearance": {
            "font_size": 14,
            "color": {
              "default": {
                "type": "hex",
                "hex": "#333333"
              }
            },
            "alignment": "start",
            "styles": [
              "italic"
            ],
            "font_families": [
              "permanent_marker",
              "casual"
            ]
          }
        }
        """

        try decodeEncodeCompare(source: json, type: ThomasViewInfo.self)
    }

    func testLabelButtonModelCodable() throws {
        let json = """
        {
          "type": "label_button",
          "identifier": "button1",
          "background_color": {
            "default": {
              "type": "hex",
              "hex": "#D32F2F",
              "alpha": 1
            }
          },
          "label": {
            "type": "label",
            "text": "start|top",
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
        }
        """

        try decodeEncodeCompare(source: json, type: ThomasViewInfo.self)
    }

    func testButtonImageModelCodable() throws {
        let icon = """
        {
          "scale": 0.4,
          "type": "icon",
          "icon": "close",
          "color": {
            "default": {
              "type": "hex",
              "hex": "#000000",
              "alpha": 1
            },
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
                "platform": "android",
                "dark_mode": true,
                "color": {
                  "type": "hex",
                  "hex": "#FFFFFF",
                  "alpha": 1
                }
              }
            ]
          }
        }
        """

        try decodeEncodeCompare(source: icon, type:  ThomasViewInfo.ImageButton.ButtonImage.self)

        let url = """
        {
          "type": "url",
          "url": "https://upload.wikimedia.org/wikipedia/en/thumb/8/8b/Airship_2019_logo.png"
        }
        """

        try decodeEncodeCompare(source: url, type: ThomasViewInfo.ImageButton.ButtonImage.self)
    }

    func testValidationInfoCoding() throws {
        let json = """
    {
        "required": true,
        "on_error": {
            "state_actions": [
                {
                  "type": "set",
                  "key": "is_valid",
                  "value": false
                }
            ]
        },
       "on_edit": {
            "state_actions": [
                {
                    "type": "clear"
                }
            ]
        },
        "on_valid": {
            "state_actions": [
             {
                  "type": "set",
                  "key": "is_valid",
                  "value": false
                }
            ]
        }
    }
    """

        try decodeEncodeCompare(source: json, type: ThomasValidationInfo.self)

        // Test optional fields
        let minimalJson = """
    {
    }
    """

        try decodeEncodeCompare(source: minimalJson, type: ThomasValidationInfo.self)
    }

    func testImageButtonCodable() throws {
        let json = """
        {
          "type": "image_button",
          "image": {
            "scale": 0.4,
            "type": "icon",
            "icon": "close",
            "color": {
              "default": {
                "type": "hex",
                "hex": "#000000",
                "alpha": 1
              },
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
                  "platform": "android",
                  "dark_mode": true,
                  "color": {
                    "type": "hex",
                    "hex": "#FFFFFF",
                    "alpha": 1
                  }
                }
              ]
            }
          },
          "identifier": "dismiss_button",
          "button_click": [
            "dismiss"
          ]
        }
        """

        try decodeEncodeCompare(source: json, type: ThomasViewInfo.self)
    }

    func testEmptyViewModelCodable() throws {
        let json = """
        {
          "type": "empty_view",
          "background_color": {
            "default": {
              "type": "hex",
              "hex": "#00FF00",
              "alpha": 0.5
            }
          }
        }
        """

        try decodeEncodeCompare(source: json, type: ThomasViewInfo.self)
    }

    func testPagerGestureModelCodable() throws {
        let swipe = """
        {
          "identifier": "63a41161-9322-4425-a940-fa928665459e_swipe_up",
          "type": "swipe",
          "direction": "up",
          "behavior": {
            "behaviors": [
              "dismiss"
            ]
          }
        }
        """
        try decodeEncodeCompare(source: swipe, type: ThomasViewInfo.Pager.Gesture.self)

        let tap = """
        {
          "identifier": "63a41161-9322-4425-a940-fa928665459e_tap_start",
          "type": "tap",
          "location": "start",
          "behavior": {
            "behaviors": [
              "pager_previous"
            ]
          }
        }
        """
        try decodeEncodeCompare(source: tap, type: ThomasViewInfo.Pager.Gesture.self)

        let hold = """
        {
          "type": "hold",
          "identifier": "hold-gesture-any-id",
          "press_behavior": {
            "behaviors": [
              "pager_pause"
            ]
          },
          "release_behavior": {
            "behaviors": [
              "pager_resume"
            ]
          }
        }
        """
        try decodeEncodeCompare(source: hold, type: ThomasViewInfo.Pager.Gesture.self)
    }

    func testPagerIndicatorModelCodable() throws {
        let json = """
        {
          "type": "pager_indicator",
          "border": {
            "radius": 8
          },
          "spacing": 4,
          "bindings": {
            "selected": {
              "shapes": [
                {
                  "type": "ellipse",
                  "aspect_ratio": 1,
                  "scale": 0.75,
                  "color": {
                    "default": {
                      "type": "hex",
                      "hex": "#000000",
                      "alpha": 1
                    }
                  }
                }
              ]
            },
            "unselected": {
              "shapes": [
                {
                  "type": "ellipse",
                  "aspect_ratio": 1,
                  "scale": 0.75,
                  "border": {
                    "stroke_width": 1,
                    "stroke_color": {
                      "default": {
                        "type": "hex",
                        "hex": "#333333",
                        "alpha": 1
                      }
                    }
                  },
                  "color": {
                    "default": {
                      "type": "hex",
                      "hex": "#ffffff",
                      "alpha": 1
                    }
                  }
                }
              ]
            }
          }
        }
        """
        try decodeEncodeCompare(source: json, type: ThomasViewInfo.self)
    }

    func testStoryIndicatorModelCodable() throws {
        let json = """
        {
          "type": "story_indicator",
          "source": {
            "type": "pager"
          },
          "style": {
            "type": "linear_progress",
            "direction": "horizontal",
            "sizing": "equal",
            "spacing": 4,
            "progress_color": {
              "default": {
                "type": "hex",
                "hex": "#AAAAAA",
                "alpha": 1
              }
            },
            "track_color": {
              "default": {
                "type": "hex",
                "hex": "#AAAAAA",
                "alpha": 0.5
              }
            }
          }
        }
        """
        try decodeEncodeCompare(source: json, type: ThomasViewInfo.self)
    }

    func testToggleStyleModelCodable() throws {
        let switchStyle = """
        {
          "type": "switch",
          "toggle_colors": {
            "on": {
              "default": {
                "type": "hex",
                "hex": "#00FF00",
                "alpha": 1
              }
            },
            "off": {
              "default": {
                "type": "hex",
                "hex": "#FF0000",
                "alpha": 1
              }
            }
          }
        }
        """
        try decodeEncodeCompare(source: switchStyle, type: ThomasToggleStyleInfo.self)

        let checkbox = """
        {
          "bindings": {
            "selected": {
              "shapes": [
                {
                  "border": {
                    "radius": 2,
                    "stroke_color": {
                      "default": {
                        "type": "hex",
                        "alpha": 1,
                        "hex": "#000000",
                      }
                    },
                    "stroke_width": 1
                  },
                  "color": {
                    "default": {
                      "type": "hex",
                      "alpha": 1,
                      "hex": "#DDDDDD",
                    }
                  },
                  "scale": 1,
                  "type": "ellipse"
                }
              ]
            },
            "unselected": {
              "shapes": [
                {
                  "border": {
                    "radius": 2,
                    "stroke_color": {
                      "default": {
                        "type": "hex",
                        "alpha": 1,
                        "hex": "#000000",
                      }
                    },
                    "stroke_width": 1
                  },
                  "color": {
                    "default": {
                      "type": "hex",
                      "alpha": 1,
                      "hex": "#FFFFFF",
                    }
                  },
                  "scale": 1,
                  "type": "ellipse"
                }
              ]
            }
          },
          "type": "checkbox"
        }
        """
        try decodeEncodeCompare(source: checkbox, type: ThomasToggleStyleInfo.self)
    }

    func testCheckboxModelCodable() throws {
        let json = """
        {
          "type": "checkbox",
          "reporting_value": "moving boxes",
          "style": {
            "type": "checkbox",
            "bindings": {
              "selected": {
                "shapes": [
                  {
                    "type": "rectangle",
                    "scale": 0.5,
                    "aspect_ratio": 1,
                    "color": {
                      "default": {
                        "type": "hex",
                        "hex": "#66FF66",
                        "alpha": 1
                      }
                    },
                    "border": {
                      "stroke_width": 2,
                      "radius": 5,
                      "stroke_color": {
                        "default": {
                          "type": "hex",
                          "hex": "#333333",
                          "alpha": 1
                        }
                      }
                    }
                  }
                ],
                "icon": {
                  "type": "icon",
                  "icon": "checkmark",
                  "color": {
                    "default": {
                      "type": "hex",
                      "hex": "#333333",
                      "alpha": 1
                    }
                  },
                  "scale": 0.4
                }
              },
              "unselected": {
                "shapes": [
                  {
                    "type": "rectangle",
                    "scale": 0.5,
                    "aspect_ratio": 1,
                    "color": {
                      "default": {
                        "type": "hex",
                        "hex": "#FF6666",
                        "alpha": 1
                      }
                    },
                    "border": {
                      "stroke_width": 2,
                      "radius": 5,
                      "stroke_color": {
                        "default": {
                          "type": "hex",
                          "hex": "#333333",
                          "alpha": 1
                        }
                      }
                    }
                  }
                ],
                "icon": {
                  "type": "icon",
                  "icon": "close",
                  "color": {
                    "default": {
                      "type": "hex",
                      "hex": "#333333",
                      "alpha": 1
                    }
                  },
                  "scale": 0.4
                }
              }
            }
          }
        }
        """
        try decodeEncodeCompare(source: json, type: ThomasViewInfo.self)
    }

    func testRadioModelCodable() throws {
        let json = """
        {
          "reporting_value": "very_satisfied",
          "attribute_value": "VerySatisfied",
          "style": {
            "bindings": {
              "selected": {
                "shapes": [
                  {
                    "border": {
                      "radius": 2,
                      "stroke_color": {
                        "default": {
                          "type": "hex",
                          "alpha": 1,
                          "hex": "#000000",
                        }
                      },
                      "stroke_width": 1
                    },
                    "color": {
                      "default": {
                        "type": "hex",
                        "alpha": 1,
                        "hex": "#DDDDDD",
                      }
                    },
                    "scale": 1,
                    "type": "ellipse"
                  }
                ]
              },
              "unselected": {
                "shapes": [
                  {
                    "border": {
                      "radius": 2,
                      "stroke_color": {
                        "default": {
                          "type": "hex",
                          "alpha": 1,
                          "hex": "#000000",
                        }
                      },
                      "stroke_width": 1
                    },
                    "color": {
                      "default": {
                        "type": "hex",
                        "alpha": 1,
                        "hex": "#FFFFFF",
                      }
                    },
                    "scale": 1,
                    "type": "ellipse"
                  }
                ]
              }
            },
            "type": "checkbox"
          },
          "type": "radio_input"
        }
        """
        try decodeEncodeCompare(source: json, type: ThomasViewInfo.self)
    }

    func testTextInputModelCodable() throws {
        let json = """
        {
          "background_color": {
            "default": {
              "type": "hex",
              "hex": "#eae9e9",
              "alpha": 1
            }
          },
          "border": {
            "radius": 2,
            "stroke_width": 1,
            "stroke_color": {
              "default": {
                "type": "hex",
                "hex": "#63656b",
                "alpha": 1
              }
            }
          },
          "type": "text_input",
          "text_appearance": {
            "alignment": "start",
            "font_size": 14,
            "color": {
              "default": {
                "type": "hex",
                "hex": "#000000",
                "alpha": 1
              }
            }
          },
          "identifier": "4e1a5c5f-a4cb-4599-a612-199e06aeaebd",
          "input_type": "text_multiline",
          "required": false
        }
        """
        try decodeEncodeCompare(source: json, type: ThomasViewInfo.self)
    }

    func testTextInputModelWithRegistrationCodable() throws {
        let json = """
        {
          "background_color": {
            "default": {
              "type": "hex",
              "hex": "#eae9e9",
              "alpha": 1
            }
          },
          "border": {
            "radius": 2,
            "stroke_width": 1,
            "stroke_color": {
              "default": {
                "type": "hex",
                "hex": "#63656b",
                "alpha": 1
              }
            }
          },
          "type": "text_input",
          "text_appearance": {
            "alignment": "start",
            "font_size": 14,
            "color": {
              "default": {
                "type": "hex",
                "hex": "#000000",
                "alpha": 1
              }
            }
          },
          "identifier": "4e1a5c5f-a4cb-4599-a612-199e06aeaebd",
          "input_type": "email",
          "email_registration": {
            "type": "double_opt_in",
            "properties": {
               "from": "iax"
            }
          },
          "required": false
        }
        """
        try decodeEncodeCompare(source: json, type: ThomasViewInfo.self)
    }

    func testScoreStyleModelCodable() throws {
        let json = """
        {
          "type": "number_range",
          "start": 0,
          "end": 10,
          "spacing": 4,
          "bindings": {
            "selected": {
              "shapes": [
                {
                  "type": "rectangle",
                  "aspect_ratio": 1,
                  "scale": 1,
                  "color": {
                    "default": {
                      "type": "hex",
                      "hex": "#000000",
                      "alpha": 1
                    }
                  }
                },
                {
                  "type": "ellipse",
                  "aspect_ratio": 1.5,
                  "scale": 1,
                  "border": {
                    "stroke_width": 2,
                    "stroke_color": {
                      "default": {
                        "type": "hex",
                        "hex": "#999999",
                        "alpha": 1
                      }
                    }
                  },
                  "color": {
                    "default": {
                      "type": "hex",
                      "hex": "#FFFFFF",
                      "alpha": 0
                    }
                  }
                }
              ],
              "text_appearance": {
                "font_size": 14,
                "color": {
                  "default": {
                    "type": "hex",
                    "hex": "#FFFFFF",
                    "alpha": 1
                  }
                },
                "font_families": [
                  "permanent_marker"
                ]
              }
            },
            "unselected": {
              "shapes": [
                {
                  "type": "ellipse",
                  "aspect_ratio": 1.5,
                  "scale": 1,
                  "border": {
                    "stroke_width": 2,
                    "stroke_color": {
                      "default": {
                        "type": "hex",
                        "hex": "#999999",
                        "alpha": 1
                      }
                    }
                  },
                  "color": {
                    "default": {
                      "type": "hex",
                      "hex": "#FFFFFF",
                      "alpha": 1
                    }
                  }
                }
              ],
              "text_appearance": {
                "font_size": 14,
                "styles": [
                  "bold"
                ],
                "color": {
                  "default": {
                    "type": "hex",
                    "hex": "#333333",
                    "alpha": 1
                  }
                }
              }
            }
          }
        }
        """
        try decodeEncodeCompare(source: json, type: ThomasViewInfo.Score.ScoreStyle.self)
    }

    func testScoreModelCodable() throws {
        let json = """
        {
          "type": "score",
          "identifier": "nps_zero_to_ten",
          "required": true,
          "style": {
            "type": "number_range",
            "spacing": 2,
            "start": 0,
            "end": 10,
            "bindings": {
              "selected": {
                "shapes": [
                  {
                    "type": "rectangle",
                    "color": {
                      "default": {
                        "type": "hex",
                        "hex": "#000000",
                        "alpha": 1
                      }
                    }
                  }
                ],
                "text_appearance": {
                  "font_size": 12,
                  "styles": [
                    "bold"
                  ],
                  "color": {
                    "default": {
                      "type": "hex",
                      "hex": "#ffffff",
                      "alpha": 1
                    }
                  }
                }
              },
              "unselected": {
                "shapes": [
                  {
                    "type": "rectangle",
                    "border": {
                      "stroke_width": 1,
                      "stroke_color": {
                        "default": {
                          "type": "hex",
                          "hex": "#999999",
                          "alpha": 1
                        }
                      }
                    },
                    "color": {
                      "default": {
                        "type": "hex",
                        "hex": "#dedede",
                        "alpha": 1
                      }
                    }
                  }
                ],
                "text_appearance": {
                  "font_size": 12,
                  "color": {
                    "default": {
                      "type": "hex",
                      "hex": "#666666",
                      "alpha": 1
                    }
                  }
                }
              }
            }
          }
        }
        """
        try decodeEncodeCompare(source: json, type: ThomasViewInfo.Score.self)
    }

    func testToggleModelCodable() throws {
        let json = """
        {
          "type": "toggle",
          "identifier": "hide",
          "event_handlers": [
            {
              "type": "form_input",
              "state_actions": [
                {
                  "type": "set_form_value",
                  "key": "hide"
                }
              ]
            }
          ],
          "style": {
            "type": "switch",
            "toggle_colors": {
              "on": {
                "default": {
                  "type": "hex",
                  "hex": "#00FF00",
                  "alpha": 1
                }
              },
              "off": {
                "default": {
                  "type": "hex",
                  "hex": "#FF0000",
                  "alpha": 1
                }
              }
            }
          }
        }
        """
        try decodeEncodeCompare(source: json, type: ThomasViewInfo.Toggle.self)
    }

    func testContainerModelCodable() throws {
        let json = """
        {
          "type": "container",
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
              "margin": {
                "top": 75,
                "bottom": 50,
                "start": 50,
                "end": 50
              },
              "view": {
                "type": "label",
                "text": "Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. In arcu cursus euismod quis viverra nibh. Lobortis feugiat vivamus at augue eget arcu dictum. Imperdiet dui accumsan sit amet nulla. Ultrices neque ornare aenean euismod elementum. Tincidunt id aliquet risus feugiat in ante metus dictum.",
                "text_appearance": {
                  "font_size": 14,
                  "color": {
                    "default": {
                      "type": "hex",
                      "hex": "#333333"
                    }
                  },
                  "alignment": "start",
                  "styles": [
                    "italic"
                  ],
                  "font_families": [
                    "permanent_marker",
                    "casual"
                  ]
                }
              }
            }
          ]
        }
        """
        try decodeEncodeCompare(source: json, type: ThomasViewInfo.Container.self)
    }

    func testLinearLayoutModelCodable() throws {
        let json = """
        {
          "type": "linear_layout",
          "items": [
            {
              "margin": {
                "start": 0,
                "end": 0,
                "top": 0,
                "bottom": 0
              },
              "size": {
                "width": "100%",
                "height": "auto"
              },
              "view": {
                "media_type": "image",
                "url": "https://media3.giphy.com/media/tBvPFCFQHSpEI/giphy.gif",
                "media_fit": "center_inside",
                "type": "media"
              }
            },
            {
              "margin": {
                "bottom": 0,
                "end": 0,
                "top": 0,
                "start": 0
              },
              "view": {
                "media_fit": "center_inside",
                "type": "media",
                "video": {
                  "muted": true,
                  "aspect_ratio": 1.7777777777777777,
                  "autoplay": false,
                  "show_controls": true,
                  "loop": false
                },
                "url": "https://www.youtube.com/embed/a3ICNMQW7Ok/?autoplay=0&controls=1&loop=0&mute=1",
                "media_type": "youtube"
              },
              "size": {
                "width": "100%",
                "height": "auto"
              }
            },
            {
              "size": {
                "width": "100%",
                "height": "100%"
              },
              "view": {
                "type": "linear_layout",
                "items": [],
                "direction": "horizontal"
              }
            }
          ],
          "direction": "vertical"
        }
        """
        try decodeEncodeCompare(source: json, type: ThomasViewInfo.self)
    }

    func testScrollLayoutModelCodable() throws {
        let json = """
        {
          "type": "scroll_layout",
          "direction": "vertical",
          "view": {
            "type": "linear_layout",
            "direction": "vertical",
            "items": [
              {
                "size": {
                  "height": "auto",
                  "width": "100%"
                },
                "view": {
                  "type": "media",
                  "media_fit": "fit_crop",
                  "position": {
                    "horizontal": "center",
                    "vertical": "center"
                  },
                  "url": "https://hangar-dl.urbanairshi.com/binary/public/Hx7SIqHqQDmFj6aruaAFcQ/34be6e8d-31d0-499b-886e-2b29459cb472",
                  "media_type": "image"
                }
              }
            ]
          }
        }
        """
        try decodeEncodeCompare(source: json, type: ThomasViewInfo.self)
    }

    func testPagerModelCodable() throws {
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
            },
            {
              "identifier": "page2",
              "view": {
                "type": "empty_view",
                "background_color": {
                  "default": {
                    "type": "hex",
                    "hex": "#FFFF00",
                    "alpha": 0.5
                  }
                }
              }
            },
            {
              "identifier": "page2",
              "view": {
                "type": "empty_view",
                "background_color": {
                  "default": {
                    "type": "hex",
                    "hex": "#FF00FF",
                    "alpha": 0.5
                  }
                }
              }
            }
          ]
        }
        """
        try decodeEncodeCompare(source: json, type: ThomasViewInfo.self)
    }

    func testPagerControllerModelCodable() throws {
        let json = """
        {
          "type": "pager_controller",
          "identifier": "6ab1531a-fcb3-44b4-91d7-52db73ae7cd9",
          "view": {
            "type": "linear_layout",
            "direction": "vertical",
            "items": [
              {
                "size": {
                  "height": "100%",
                  "width": "100%"
                },
                "view": {
                  "type": "container",
                  "items": [
                    {
                      "position": {
                        "horizontal": "center",
                        "vertical": "center"
                      },
                      "size": {
                        "width": "100%",
                        "height": "100%"
                      },
                      "view": {
                        "type": "pager",
                        "disable_swipe": true,
                        "items": [
                          {
                            "identifier": "c36a5103-0a8d-4e34-b7b7-331ec1cbc87e",
                            "view": {
                              "type": "container",
                              "items": [
                                {
                                  "size": {
                                    "width": "100%",
                                    "height": "100%"
                                  },
                                  "position": {
                                    "horizontal": "center",
                                    "vertical": "center"
                                  },
                                  "view": {
                                    "type": "container",
                                    "items": [
                                      {
                                        "margin": {
                                          "bottom": 16
                                        },
                                        "position": {
                                          "horizontal": "center",
                                          "vertical": "center"
                                        },
                                        "size": {
                                          "width": "100%",
                                          "height": "100%"
                                        },
                                        "view": {
                                          "type": "linear_layout",
                                          "direction": "vertical",
                                          "items": [
                                            {
                                              "size": {
                                                "width": "100%",
                                                "height": "100%"
                                              },
                                              "view": {
                                                "type": "scroll_layout",
                                                "direction": "vertical",
                                                "view": {
                                                  "type": "linear_layout",
                                                  "direction": "vertical",
                                                  "items": [
                                                    {
                                                      "size": {
                                                        "width": "100%",
                                                        "height": "auto"
                                                      },
                                                      "margin": {
                                                        "top": 48,
                                                        "bottom": 8,
                                                        "start": 16,
                                                        "end": 16
                                                      },
                                                      "view": {
                                                        "type": "label",
                                                        "text": "This is test",
                                                        "text_appearance": {
                                                          "font_size": 30,
                                                          "color": {
                                                            "default": {
                                                              "type": "hex",
                                                              "hex": "#000000",
                                                              "alpha": 1
                                                            },
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
                                                                "platform": "android",
                                                                "dark_mode": true,
                                                                "color": {
                                                                  "type": "hex",
                                                                  "hex": "#FFFFFF",
                                                                  "alpha": 1
                                                                }
                                                              }
                                                            ]
                                                          },
                                                          "alignment": "center",
                                                          "styles": [],
                                                          "font_families": [
                                                            "serif"
                                                          ]
                                                        }
                                                      }
                                                    },
                                                    {
                                                      "size": {
                                                        "width": "100%",
                                                        "height": "100%"
                                                      },
                                                      "view": {
                                                        "type": "linear_layout",
                                                        "direction": "horizontal",
                                                        "items": []
                                                      }
                                                    }
                                                  ]
                                                }
                                              }
                                            }
                                          ]
                                        }
                                      }
                                    ]
                                  }
                                }
                              ]
                            }
                          }
                        ]
                      },
                      "ignore_safe_area": false
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
                        "image": {
                          "scale": 0.4,
                          "type": "icon",
                          "icon": "close",
                          "color": {
                            "default": {
                              "type": "hex",
                              "hex": "#000000",
                              "alpha": 1
                            },
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
                                "platform": "android",
                                "dark_mode": true,
                                "color": {
                                  "type": "hex",
                                  "hex": "#FFFFFF",
                                  "alpha": 1
                                }
                              }
                            ]
                          }
                        },
                        "identifier": "dismiss_button",
                        "button_click": [
                          "dismiss"
                        ]
                      }
                    }
                  ]
                }
              }
            ]
          }
        }
        """
        try decodeEncodeCompare(source: json, type: ThomasViewInfo.self)
    }

    func testFormControllerModelCodable() throws {
        let json = """
        {
          "type": "form_controller",
          "identifier": "parent_form",
          "submit": "submit_event",
          "view": {
            "type": "linear_layout",
            "direction": "vertical",
            "background_color": {
              "default": {
                "type": "hex",
                "hex": "#ffffff",
                "alpha": 1
              }
            },
            "items": [
              {
                "size": {
                  "width": "auto",
                  "height": 40
                },
                "margin": {
                  "top": 8,
                  "bottom": 8,
                  "start": 16,
                  "end": 16
                },
                "view": {
                  "type": "nps_form_controller",
                  "identifier": "nps_zero_to_ten_form",
                  "nps_identifier": "nps_zero_to_ten",
                  "view": {
                    "type": "score",
                    "identifier": "nps_zero_to_ten",
                    "required": true,
                    "style": {
                      "type": "number_range",
                      "spacing": 2,
                      "start": 0,
                      "end": 10,
                      "bindings": {
                        "selected": {
                          "shapes": [
                            {
                              "type": "rectangle",
                              "color": {
                                "default": {
                                  "type": "hex",
                                  "hex": "#000000",
                                  "alpha": 1
                                }
                              }
                            }
                          ],
                          "text_appearance": {
                            "font_size": 12,
                            "styles": [
                              "bold"
                            ],
                            "color": {
                              "default": {
                                "type": "hex",
                                "hex": "#ffffff",
                                "alpha": 1
                              }
                            }
                          }
                        },
                        "unselected": {
                          "shapes": [
                            {
                              "type": "rectangle",
                              "border": {
                                "stroke_width": 1,
                                "stroke_color": {
                                  "default": {
                                    "type": "hex",
                                    "hex": "#999999",
                                    "alpha": 1
                                  }
                                }
                              },
                              "color": {
                                "default": {
                                  "type": "hex",
                                  "hex": "#dedede",
                                  "alpha": 1
                                }
                              }
                            }
                          ],
                          "text_appearance": {
                            "font_size": 12,
                            "color": {
                              "default": {
                                "type": "hex",
                                "hex": "#666666",
                                "alpha": 1
                              }
                            }
                          }
                        }
                      }
                    }
                  }
                }
              },
              {
                "size": {
                  "width": "auto",
                  "height": 24
                },
                "margin": {
                  "top": 8,
                  "bottom": 8,
                  "start": 16,
                  "end": 16
                },
                "view": {
                  "type": "nps_form_controller",
                  "identifier": "nps_zero_to_ten_form",
                  "nps_identifier": "nps_zero_to_ten",
                  "view": {
                    "type": "score",
                    "identifier": "nps_zero_to_ten",
                    "required": true,
                    "style": {
                      "type": "number_range",
                      "spacing": 8,
                      "start": 1,
                      "end": 5,
                      "bindings": {
                        "selected": {
                          "shapes": [
                            {
                              "type": "ellipse",
                              "color": {
                                "default": {
                                  "type": "hex",
                                  "hex": "#FFDD33",
                                  "alpha": 1
                                }
                              }
                            }
                          ],
                          "text_appearance": {
                            "font_size": 14,
                            "color": {
                              "default": {
                                "type": "hex",
                                "hex": "#000000",
                                "alpha": 1
                              }
                            }
                          }
                        },
                        "unselected": {
                          "shapes": [
                            {
                              "type": "ellipse",
                              "color": {
                                "default": {
                                  "type": "hex",
                                  "hex": "#3333ff",
                                  "alpha": 1
                                }
                              }
                            }
                          ],
                          "text_appearance": {
                            "font_size": 14,
                            "color": {
                              "default": {
                                "type": "hex",
                                "hex": "#ffffff",
                                "alpha": 1
                              }
                            }
                          }
                        }
                      }
                    }
                  }
                }
              },
              {
                "size": {
                  "width": "auto",
                  "height": 32
                },
                "margin": {
                  "top": 8,
                  "bottom": 8,
                  "start": 16,
                  "end": 16
                },
                "view": {
                  "type": "nps_form_controller",
                  "identifier": "nps_zero_to_ten_form",
                  "nps_identifier": "nps_zero_to_ten",
                  "view": {
                    "type": "score",
                    "identifier": "nps_zero_to_ten",
                    "required": true,
                    "style": {
                      "type": "number_range",
                      "spacing": 8,
                      "start": 97,
                      "end": 105,
                      "bindings": {
                        "selected": {
                          "shapes": [
                            {
                              "type": "ellipse",
                              "color": {
                                "default": {
                                  "type": "hex",
                                  "hex": "#FF0000",
                                  "alpha": 1
                                }
                              }
                            }
                          ],
                          "text_appearance": {
                            "font_size": 14,
                            "color": {
                              "default": {
                                "type": "hex",
                                "hex": "#000000",
                                "alpha": 1
                              }
                            }
                          }
                        },
                        "unselected": {
                          "shapes": [
                            {
                              "type": "ellipse",
                              "color": {
                                "default": {
                                  "type": "hex",
                                  "hex": "#0000FF",
                                  "alpha": 1
                                }
                              }
                            }
                          ],
                          "text_appearance": {
                            "font_size": 14,
                            "color": {
                              "default": {
                                "type": "hex",
                                "hex": "#ffffff",
                                "alpha": 1
                              }
                            }
                          }
                        }
                      }
                    }
                  }
                }
              },
              {
                "size": {
                  "width": "100%",
                  "height": "auto"
                },
                "margin": {
                  "top": 16,
                  "bottom": 16,
                  "start": 16,
                  "end": 16
                },
                "view": {
                  "type": "label_button",
                  "identifier": "SUBMIT_BUTTON",
                  "background_color": {
                    "default": {
                      "type": "hex",
                      "hex": "#000000",
                      "alpha": 1
                    }
                  },
                  "button_click": [
                    "form_submit",
                    "cancel"
                  ],
                  "enabled": [
                    "form_validation"
                  ],
                  "label": {
                    "type": "label",
                    "text": "SEND IT!",
                    "text_appearance": {
                      "font_size": 14,
                      "alignment": "center",
                      "color": {
                        "default": {
                          "type": "hex",
                          "hex": "#ffffff",
                          "alpha": 1
                        }
                      }
                    }
                  }
                }
              }
            ]
          }
        }
        """
        try decodeEncodeCompare(source: json, type: ThomasViewInfo.self)
    }

    func testCheckboxControllerModelCodable() throws {
        let json = """
        {
          "type": "checkbox_controller",
          "identifier": "checkboxes",
          "view": {
            "type": "linear_layout",
            "direction": "vertical",
            "items": [
              {
                "size": {
                  "width": "100%",
                  "height": "auto"
                },
                "view": {
                  "type": "linear_layout",
                  "direction": "horizontal",
                  "items": [
                    {
                      "size": {
                        "width": "auto",
                        "height": "auto"
                      },
                      "margin": {
                        "top": 0
                      },
                      "view": {
                        "type": "checkbox",
                        "reporting_value": "check_cyan",
                        "event_handlers": [
                          {
                            "type": "tap",
                            "state_actions": [
                              {
                                "type": "set",
                                "key": "last_check",
                                "value": "cyan"
                              }
                            ]
                          }
                        ],
                        "style": {
                          "type": "checkbox",
                          "bindings": {
                            "selected": {
                              "icon": {
                                "type": "icon",
                                "icon": "checkmark",
                                "color": {
                                  "default": {
                                    "type": "hex",
                                    "hex": "#000000",
                                    "alpha": 1
                                  }
                                },
                                "scale": 0.5
                              },
                              "shapes": [
                                {
                                  "border": {
                                    "radius": 5,
                                    "stroke_color": {
                                      "default": {
                                        "type": "hex",
                                        "hex": "#000000",
                                        "alpha": 1
                                      }
                                    },
                                    "stroke_width": 2
                                  },
                                  "color": {
                                    "default": {
                                      "type": "hex",
                                      "hex": "#00ffff",
                                      "alpha": 1
                                    }
                                  },
                                  "scale": 1,
                                  "type": "rectangle"
                                }
                              ]
                            },
                            "unselected": {
                              "shapes": [
                                {
                                  "border": {
                                    "radius": 5,
                                    "stroke_color": {
                                      "default": {
                                        "type": "hex",
                                        "hex": "#000000",
                                        "alpha": 0.5
                                      }
                                    },
                                    "stroke_width": 1
                                  },
                                  "color": {
                                    "default": {
                                      "type": "hex",
                                      "hex": "#00ffff",
                                      "alpha": 0.5
                                    }
                                  },
                                  "scale": 1,
                                  "type": "rectangle"
                                }
                              ]
                            }
                          }
                        }
                      }
                    },
                    {
                      "size": {
                        "width": "auto",
                        "height": "auto"
                      },
                      "margin": {
                        "start": 8
                      },
                      "view": {
                        "type": "label",
                        "text": "<-- Check it",
                        "text_appearance": {
                          "color": {
                            "default": {
                              "type": "hex",
                              "hex": "#000000",
                              "alpha": 1
                            }
                          },
                          "font_size": 14,
                          "alignment": "start"
                        },
                        "visibility": {
                          "default": true,
                          "invert_when_state_matches": {
                            "key": "last_check",
                            "value": {
                              "is_present": true
                            }
                          }
                        }
                      }
                    },
                    {
                      "size": {
                        "width": "auto",
                        "height": "auto"
                      },
                      "margin": {
                        "start": 8
                      },
                      "view": {
                        "type": "label",
                        "text": "<-- Tapped last",
                        "text_appearance": {
                          "color": {
                            "default": {
                              "type": "hex",
                              "hex": "#000000",
                              "alpha": 1
                            }
                          },
                          "font_size": 14,
                          "alignment": "start"
                        },
                        "visibility": {
                          "default": false,
                          "invert_when_state_matches": {
                            "key": "last_check",
                            "value": {
                              "equals": "cyan"
                            }
                          }
                        }
                      }
                    }
                  ]
                }
              },
              {
                "size": {
                  "width": "100%",
                  "height": "auto"
                },
                "margin": {
                  "top": 4
                },
                "view": {
                  "type": "linear_layout",
                  "direction": "horizontal",
                  "items": [
                    {
                      "size": {
                        "width": "auto",
                        "height": "auto"
                      },
                      "view": {
                        "type": "checkbox",
                        "reporting_value": "check_magenta",
                        "event_handlers": [
                          {
                            "type": "tap",
                            "state_actions": [
                              {
                                "type": "set",
                                "key": "last_check",
                                "value": "magenta"
                              }
                            ]
                          }
                        ],
                        "style": {
                          "type": "checkbox",
                          "bindings": {
                            "selected": {
                              "icon": {
                                "type": "icon",
                                "icon": "checkmark",
                                "color": {
                                  "default": {
                                    "type": "hex",
                                    "hex": "#000000",
                                    "alpha": 1
                                  }
                                },
                                "scale": 0.5
                              },
                              "shapes": [
                                {
                                  "border": {
                                    "radius": 5,
                                    "stroke_color": {
                                      "default": {
                                        "type": "hex",
                                        "hex": "#000000",
                                        "alpha": 1
                                      }
                                    },
                                    "stroke_width": 2
                                  },
                                  "color": {
                                    "default": {
                                      "type": "hex",
                                      "hex": "#ff00ff",
                                      "alpha": 1
                                    }
                                  },
                                  "scale": 1,
                                  "type": "rectangle"
                                }
                              ]
                            },
                            "unselected": {
                              "shapes": [
                                {
                                  "border": {
                                    "radius": 5,
                                    "stroke_color": {
                                      "default": {
                                        "type": "hex",
                                        "hex": "#000000",
                                        "alpha": 0.5
                                      }
                                    },
                                    "stroke_width": 1
                                  },
                                  "color": {
                                    "default": {
                                      "type": "hex",
                                      "hex": "#ff00ff",
                                      "alpha": 0.5
                                    }
                                  },
                                  "scale": 1,
                                  "type": "rectangle"
                                }
                              ]
                            }
                          }
                        }
                      }
                    },
                    {
                      "size": {
                        "width": "auto",
                        "height": "auto"
                      },
                      "margin": {
                        "start": 8
                      },
                      "view": {
                        "type": "label",
                        "text": "<-- Check it",
                        "text_appearance": {
                          "color": {
                            "default": {
                              "type": "hex",
                              "hex": "#000000",
                              "alpha": 1
                            }
                          },
                          "font_size": 14,
                          "alignment": "start"
                        },
                        "visibility": {
                          "default": true,
                          "invert_when_state_matches": {
                            "key": "last_check",
                            "value": {
                              "is_present": true
                            }
                          }
                        }
                      }
                    },
                    {
                      "size": {
                        "width": "auto",
                        "height": "auto"
                      },
                      "margin": {
                        "start": 8
                      },
                      "view": {
                        "type": "label",
                        "text": "<-- Tapped last",
                        "text_appearance": {
                          "color": {
                            "default": {
                              "type": "hex",
                              "hex": "#000000",
                              "alpha": 1
                            }
                          },
                          "font_size": 14,
                          "alignment": "start"
                        },
                        "visibility": {
                          "default": false,
                          "invert_when_state_matches": {
                            "key": "last_check",
                            "value": {
                              "equals": "magenta"
                            }
                          }
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
        try decodeEncodeCompare(source: json, type: ThomasViewInfo.self)
    }

    func testRadioInputControllerModelCodable() throws {
        let json = """
        {
          "identifier": "52fd50d9-c899-4887-8210-9669cb27188c",
          "type": "radio_input_controller",
          "attribute_name": {
            "channel": "HowSatisfiedAreYou"
          },
          "event_handlers": [
            {
              "type": "form_input",
              "state_actions": [
                {
                  "type": "set_form_value",
                  "key": "neat"
                }
              ]
            }
          ],
          "view": {
              "type": "label",
              "text": "Sup Buddy",
              "text_appearance": {
                "font_size": 14,
                "color": {
                  "default": {
                    "type": "hex",
                    "hex": "#333333"
                  }
                },
                "alignment": "start",
                "styles": [
                  "italic"
                ],
                "font_families": [
                  "permanent_marker",
                  "casual"
                ]
              }
            }
        }
        """
        try decodeEncodeCompare(source: json, type: ThomasViewInfo.self)
    }
    

    func testStateControllerModelCodable() throws {
        let json = """
        {
           "type":"state_controller",
           "view":{
              "type":"linear_layout",
              "direction":"vertical",
              "items":[
                 {
                    "size": {
                      "width": "auto",
                      "height": "auto"
                    },
                    "view":{
                       "type":"label",
                       "text":"Sup Buddy",
                       "text_appearance":{
                          "font_size":14,
                          "color":{
                             "default":{
                                "type": "hex",
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
                 }
              ]
           }
        }
        """
        try decodeEncodeCompare(source: json, type: ThomasViewInfo.self)
    }

    func testActionPayload() throws {
        let payload = ThomasActionsPayload(value: try AirshipJSON.wrap(["foo": "bar"]))
        let encoded = try JSONEncoder().encode(payload)
        let decoded = try JSONDecoder().decode(ThomasActionsPayload.self, from: encoded)
        XCTAssertEqual(payload, decoded)
    }

    func testActionPayloadPlatformOverrides() throws {
        let payload = ThomasActionsPayload(value: try AirshipJSON.wrap([
            "foo": "bar",
            "shouldnt_change": "value",
            "platform_action_overrides": [
                "ios": [
                    "foo": "bar2",
                    "added": "override"
                ]
            ]
        ]))
        
        let encoded = try JSONEncoder().encode(payload)
        let decoded = try JSONDecoder().decode(ThomasActionsPayload.self, from: encoded)
        XCTAssertEqual(payload, decoded)

        XCTAssertEqual("bar2", payload.value.object?["foo"]?.string)
        XCTAssertEqual("value", payload.value.object?["shouldnt_change"]?.string)
        XCTAssertEqual("override", payload.value.object?["added"]?.string)
    }

    private func decodeEncodeCompare<T: Codable & Equatable>(source: String, type: T.Type) throws {
        let decoder = JSONDecoder()
        let encoder = JSONEncoder()

        let decoded = try decoder.decode(type, from: source.data(using: .utf8)!)
        let json = try encoder.encode(decoded)
        let restored = try decoder.decode(type, from: json)

        XCTAssertEqual(restored, decoded)

        let inputJson = try JSONSerialization.jsonObject(with: source.data(using: .utf8)!) as! [String: Any]
        let encodedJson = try JSONSerialization.jsonObject(with: json) as! [String: Any]

        XCTAssertEqual(try AirshipJSON.wrap(inputJson), try AirshipJSON.wrap(encodedJson))
    }
}
