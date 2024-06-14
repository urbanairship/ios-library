/* Copyright Airship and Contributors */

import AirshipCore
import XCTest

@testable import AirshipPreferenceCenter

class PreferenceCenterDecoderTest: XCTestCase {
    func testForm() throws {
        let testPayload: String = 
"""
{
          "id": "cool-prefs",
          "display": {
            "name": "Cool Prefs",
            "description": "Preferences but they're cool"
          },
          "sections": [
            {
              "id": "a2db6801-c766-44d7-b5d6-070ca64421b2",
              "type": "section",
              "items": [
                {
                  "id": "a2db6801-c766-44d7-b5d6-070ca64421b3",
                  "type": "contact_management",
                  "platform": "email",
                  "display": {
                    "name": "Email Addresses",
                    "description": "Addresses associated with your account."
                  },
                  "registration_options": {
                    "address_label": "Email address",
                    "resend": {
                      "interval": 10,
                      "message": "Pending verification",
                      "button": {
                        "text": "Resend",
                        "content_description": "Resend a verification message to this email address"
                      },
                      "on_success": {
                        "name": "Verification resent",
                        "description": "Check your inbox for a new confirmation email.",
                        "button": {
                          "text": "Ok",
                          "content_description": "Close prompt"
                        }
                      }
                    },
                    "error_messages": {
                      "invalid": "Please enter a valid email address.",
                      "default": "Uh oh, something went wrong."
                    }
                  },
                  "add": {
                    "button": {
                      "text": "Add email",
                      "content_description": "Add a new email address"
                    },
                    "view": {
                      "type": "prompt",
                      "display": {
                        "title": "Add an email address",
                        "description": "You will receive a confirmation email to verify your address.",
                        "footer": "Does anyone read our [Terms and Conditions](https://example.com) and [Privacy Policy](https://example.com)?"
                      },
                      "submit_button": {
                        "text": "Send",
                        "content_description": "Send a message to this email address"
                      },
                      "cancel_button": {
                        "text": "Cancel"
                      },
                      "close_button": {
                        "content_description": "Close"
                      },
                      "on_submit": {
                        "name": "Oh no, it worked.",
                        "description": "Hope you like emails.",
                        "button": {
                          "text": "Ok, dang"
                        }
                      }
                    }
                  },
                  "remove": {
                    "button": {
                      "content_description": "Opt out and remove this email address"
                    },
                    "view": {
                      "type": "prompt",
                      "display": {
                        "title": "Remove email address?",
                        "description": "I thought you liked emails."
                      },
                      "submit_button": {
                        "text": "Yes",
                        "content_description": "Confirm opt out"
                      },
                      "cancel_button": {
                        "text": "No",
                        "content_description": "Cancel opt out"
                      },
                      "close_button": {
                        "content_description": "Close"
                      },
                      "on_submit": {
                        "name": "Success",
                        "description": "Bye!",
                        "button": {
                          "text": "Ok",
                          "content_description": "Close prompt"
                        }
                      }
                    }
                  }
                },
                {
                  "id": "a2db6801-c766-44d7-b5d6-070ca64421b4",
                  "type": "contact_management",
                  "platform": "sms",
                  "display": {
                    "name": "Mobile Numbers"
                  },
                  "registration_options": {
                    "country_label": "Country",
                    "msisdn_label": "Phone number",
                    "resend": {
                      "interval": 10,
                      "message": "Pending verification",
                      "button": {
                        "text": "Resend",
                        "content_description": "Resend a verification message to this phone number"
                      }
                    },
                    "senders": [
                      {
                        "country_code": "+44",
                        "display_name": "United Kingdom",
                        "placeholder_text": "7010 111222",
                        "sender_id": "23450"
                      }
                    ],
                    "error_messages": {
                      "invalid": "Please enter a valid phone number.",
                      "default": "Uh oh, something went wrong."
                    }
                  },
                  "add": {
                    "view": {
                      "type": "prompt",
                      "display": {
                        "title": "Add a phone number",
                        "description": "You will receive a text message with further details.",
                        "footer": "By opting in you give us the OK to hound you forever."
                      },
                      "submit_button": {
                        "text": "Send",
                        "content_description": "Send a message to this phone number"
                      },
                      "cancel_button": {
                        "text": "Cancel"
                      },
                      "close_button": {
                        "content_description": "Close"
                      },
                      "on_submit": {
                        "name": "Oh no, it worked.",
                        "description": "Hope you like text messages.",
                        "button": {
                          "text": "Ok, dang"
                        }
                      }
                    },
                    "button": {
                      "text": "Add SMS",
                      "content_description": "Add a new phone number"
                    }
                  },
                  "remove": {
                    "button": {
                      "content_description": "Opt out and remove this phone number"
                    },
                    "view": {
                      "type": "prompt",
                      "display": {
                        "title": "Remove phone number?",
                        "description": "Your phone will buzz less."
                      },
                      "submit_button": {
                        "text": "Yes",
                        "content_description": "Confirm opt out"
                      },
                      "cancel_button": {
                        "text": "No",
                        "content_description": "Cancel opt out"
                      },
                      "close_button": {
                        "content_description": "Close"
                      },
                      "on_submit": {
                        "name": "Success",
                        "description": "Bye!",
                        "button": {
                          "text": "Ok",
                          "content_description": "Close prompt"
                        }
                      }
                    }
                  }
                }
              ]
            }
          ]
        }
"""
        let response = try! PreferenceCenterDecoder.decodeConfig(
            data: testPayload.data(using: .utf8)!
        )

        XCTAssertNotNil(response)
    }

    private func parseAndSortJSON(jsonString: String) -> String? {
        guard let data = jsonString.data(using: .utf8),
              let jsonObject = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
        else { return nil }

        let sortedData = try? JSONSerialization.data(withJSONObject: jsonObject, options: [.sortedKeys, .prettyPrinted])
        return sortedData.flatMap { String(data: $0, encoding: .utf8) }
    }
}

