/* Copyright Airship and Contributors */

import XCTest

@testable import AirshipCore

class ThomasValidationTests: XCTestCase {

    func testValidVersions() throws {
        try (AirshipLayout.minLayoutVersion...AirshipLayout.maxLayoutVersion)
            .map { self.layout(version: $0).data(using: .utf8)! }
            .forEach {
                let layout = try JSONDecoder().decode(AirshipLayout.self, from: $0)

                XCTAssertTrue(
                    layout.validate()
                )
            }
    }

    func testInvalidVersions() throws {
        try ([AirshipLayout.minLayoutVersion - 1, AirshipLayout.maxLayoutVersion + 1])
            .map { self.layout(version: $0).data(using: .utf8)! }
            .forEach {
                let layout = try JSONDecoder().decode(AirshipLayout.self, from: $0)
                XCTAssertFalse(
                    layout.validate()
                )
            }
    }

    func testInvalidPayloads() throws {
        let invalidPayloads = [
            invalidPagerOutsidePagerController,
            invalidToggleOutsideFormController,
            invalidTextInputOutsideFormController,
            invalidCheckboxControllerOutsideFormController,
            invalidScoreOutsideFormController,
            invalidRadioInputControllerOutsideFormController,
        ]


        try invalidPayloads
            .map { $0.data(using: .utf8)! }
            .forEach {
                let layout = try JSONDecoder().decode(AirshipLayout.self, from: $0)
                XCTAssertFalse(
                    layout.validate()
                )
            }
    }

    func testValidPayloads() throws {
        let validPayloads = [
            validCheckboxLayout
        ]

        try validPayloads
            .map { $0.data(using: .utf8)! }
            .forEach {
                let layout = try JSONDecoder().decode(AirshipLayout.self, from: $0)
                XCTAssertFalse(
                    layout.validate()
                )
            }
    }

    func layout(version: Int) -> String {
        """
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
            "version": \(version),
            "view": {
              "type": "empty_view",
            }
        }
        """
    }

    let invalidPagerOutsidePagerController = """
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
                "bindings": {
                    "selected": {
                        "shapes": [
                            {
                                "aspect_ratio": 1,
                                "color": {
                                    "default": {
                                        "alpha": 1,
                                        "hex": "#AAAAAA",
                                        "type": "hex"
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
                                "aspect_ratio": 1,
                                "color": {
                                    "default": {
                                        "alpha": 1,
                                        "hex": "#CCCCCC",
                                        "type": "hex"
                                    }
                                },
                                "scale": 1,
                                "type": "ellipse"
                            }
                        ]
                    }
                },
                "spacing": 4,
                "type": "pager_indicator"
            }
        }
        """

    let invalidTextInputOutsideFormController = """
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
                "background_color": {
                    "default": {
                        "alpha": 1,
                        "hex": "#eae9e9",
                        "type": "hex"
                    }
                },
                "border": {
                    "radius": 2,
                    "stroke_color": {
                        "default": {
                            "alpha": 1,
                            "hex": "#63656b",
                            "type": "hex"
                        }
                    },
                    "stroke_width": 1
                },
                "identifier": "8702f09b-9582-477f-b402-e2db1ca2a059",
                "input_type": "text",
                "required": false,
                "text_appearance": {
                    "color": {
                        "default": {
                            "alpha": 1,
                            "hex": "#000000",
                            "type": "hex"
                        }
                    },
                    "font_size": 14
                },
                "type": "text_input"
            }
        }
        """

    let invalidToggleOutsideFormController = """
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
                "type": "toggle",
                "identifier": "agree-things",
                "required": true,
                "style": {
                    "type": "checkbox",
                    "bindings": {
                        "selected": {
                            "shapes": [
                                {
                                    "type": "rectangle"
                                }
                            ],
                            "icon": {
                                "icon": "checkmark",
                                "scale": 0.8,
                                "color": {
                                    "default": {
                                        "hex": "#0000ff"
                                    }
                                }
                            }
                        },
                        "unselected": {
                            "shapes": [
                                {
                                    "type": "ellipse"
                                }
                            ]
                        }
                    }
                }
            }
        }
        """

    let invalidCheckboxControllerOutsideFormController = """
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
                "type": "toggle",
                "identifier": "agree-things",
                "required": true,
                "style": {
                    "type": "checkbox",
                    "bindings": {
                        "selected": {
                            "shapes": [
                                {
                                    "type": "rectangle"
                                }
                            ],
                            "icon": {
                                "icon": "checkmark",
                                "scale": 0.8,
                                "color": {
                                    "default": {
                                        "hex": "#0000ff"
                                    }
                                }
                            }
                        },
                        "unselected": {
                            "shapes": [
                                {
                                    "type": "ellipse"
                                }
                            ]
                        }
                    }
                }
            }
        }
        """

    let invalidRadioInputControllerOutsideFormController = """
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
                "type": "radio_input_controller",
                "identifier": "favorite_colors",
                "max_selection": 2,
                "min_selection": 1,
                "required": true,
                "view": {
                    "type": "empty_view"
                }
            }
        }
        """

    let invalidChildFormControllerOutsideFormController = """
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
                "type" : "nps_form_controller",
                "identifier": "123",
                "view" : {
                    "type": "empty_view"
                }
            }
        }
        """

    let invalidScoreOutsideFormController = """
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
                "identifier": "428851de-c070-463c-82b7-fca87ba0faa0",
                "required": true,
                "style": {
                    "bindings": {
                        "selected": {
                            "shapes": [
                                {
                                    "color": {
                                        "default": {
                                            "alpha": 1,
                                            "hex": "#000000",
                                            "type": "hex"
                                        }
                                    },
                                    "scale": 1,
                                    "type": "rectangle"
                                }
                            ],
                            "text_appearance": {
                                "color": {
                                    "default": {
                                        "alpha": 1,
                                        "hex": "#AAAAAA",
                                        "type": "hex"
                                    }
                                },
                                "font_size": 12
                            }
                        },
                        "unselected": {
                            "shapes": [
                                {
                                    "color": {
                                        "default": {
                                            "alpha": 1,
                                            "hex": "#CCCCCC",
                                            "type": "hex"
                                        }
                                    },
                                    "scale": 1,
                                    "type": "rectangle"
                                }
                            ],
                            "text_appearance": {
                                "color": {
                                    "default": {
                                        "alpha": 1,
                                        "hex": "#333333",
                                        "type": "hex"
                                    }
                                },
                                "font_size": 12
                            }
                        }
                    },
                    "end": 10,
                    "spacing": 2,
                    "start": 0,
                    "type": "number_range"
                },
                "type": "score"
            }
        }
        """

    let validCheckboxLayout = """
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
          "type": "checkbox_controller",
          "version": 1,
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
                                        "hex": "#000000",
                                        "alpha": 1
                                      }
                                    },
                                    "stroke_width": 2
                                  },
                                  "color": {
                                    "default": {
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
                                        "hex": "#000000",
                                        "alpha": 0.5
                                      }
                                    },
                                    "stroke_width": 1
                                  },
                                  "color": {
                                    "default": {
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
                                        "hex": "#000000",
                                        "alpha": 1
                                      }
                                    },
                                    "stroke_width": 2
                                  },
                                  "color": {
                                    "default": {
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
                                        "hex": "#000000",
                                        "alpha": 0.5
                                      }
                                    },
                                    "stroke_width": 1
                                  },
                                  "color": {
                                    "default": {
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
}
