/* Copyright Airship and Contributors */

import XCTest
@testable
import AirshipCore

class ThomasValidationTests: XCTestCase {
    func testValid() throws {
        let validPayloads = [ validVersion ]
        
        try validPayloads
            .map { $0.data(using: .utf8)! }
            .forEach {  XCTAssertNoThrow(try Thomas.validate(data: $0), String(data: $0, encoding: .utf8)!) }
    }
    
    func testInvalid() throws {
        let invalidPayloads = [ invalidVersionTwo,
                                invalidVersionZero,
                                invalidPagerOutsidePagerController,
                                invalidToggleOutsideFormController,
                                invalidTextInputOutsideFormController,
                                invalidCheckboxControllerOutsideFormController,
                                invalidScoreOutsideFormController,
                                invalidRadioInputControllerOutsideFormController ]
        
        try invalidPayloads
            .map { $0.data(using: .utf8)! }
            .forEach {
                XCTAssertThrowsError(try Thomas.validate(data: $0), String(data: $0, encoding: .utf8)!)
            }
    }
    
    let validVersion = """
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
              "type": "empty_view",
            }
        }
        """
    
    let invalidVersionZero = """
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
        "version": 0,
        "view": {
          "type": "empty_view",
        }
    }
    """
    
    let invalidVersionTwo = """
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
        "version": 2,
        "view": {
          "type": "empty_view",
        }
    }
    """
    
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
            "required": true
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

}
