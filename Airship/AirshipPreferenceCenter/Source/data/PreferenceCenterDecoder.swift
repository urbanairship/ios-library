/* Copyright Airship and Contributors */

import Foundation

#if canImport(AirshipCore)
import AirshipCore
#endif
class PreferenceCenterDecoder {
    private static let decoder: JSONDecoder = {
        var decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    class func decodeConfig(data: Data) throws -> PreferenceCenterConfig {
        return try self.decoder.decode(PreferenceCenterConfig.self, from: data)
    }
}

/// To inject this Preference Center comment decodeConfig(...) in the PreferenceCenterDecoder
extension PreferenceCenterDecoder {
    class func decodeConfig(data: Data? = nil) throws -> PreferenceCenterConfig {
        let data = Data(latestMockPrefCenter.utf8)
        var preferenceConfig: PreferenceCenterConfig?
        do {
            preferenceConfig = try decoder.decode(PreferenceCenterConfig.self, from: data)
            AirshipLogger.debug("\(String(describing: preferenceConfig))")
        } catch DecodingError.dataCorrupted(let context) {
            AirshipLogger.debug("\(context)")
        } catch DecodingError.keyNotFound(let key, let context) {
            AirshipLogger.debug("Key '\(key)' not found: \(context.debugDescription)")
            AirshipLogger.debug("codingPath: \(context.codingPath)")
        } catch DecodingError.valueNotFound(let value, let context) {
            AirshipLogger.debug("Value '\(value)' not found: \(context.debugDescription)")
            AirshipLogger.debug("codingPath: \(context.codingPath)")
        } catch DecodingError.typeMismatch(let type, let context) {
            AirshipLogger.debug("Type '\(type)' mismatch: \(context.debugDescription)")
            AirshipLogger.debug("codingPath: \(context.codingPath)")
        } catch {
            AirshipLogger.debug("error: \(error)")
        }

        guard let config = preferenceConfig else {
            throw AirshipErrors.error("Failed to decode PreferenceCenterConfig")
        }
        return config
    }

    private static let latestMockPrefCenter = """
{
  "id": "cool-prefs",
  "display": {
    "name": "Cool Prefs",
    "description": "Preferences but they're cool"
  },
  "sections": [
    {
      "id": "opt-in",
      "type": "section",
      "items": [
        {
          "id": "email-opt-in",
          "type": "contact_management",
          "platform": "email",
          "empty_label": "No email added",
          "display": {
            "name": "Email Addresses",
            "description": "Email address lorem ipsum dolor sit amet, consectetur adipiscing elit."
          },
          "registration_options": {
            "type": "email",
            "placeholder_text": "example@domain.com",
            "address_label": "Email address",
            "resend": {
              "interval": 5,
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
                "body": "You will receive a confirmation email to verify your address.",
                "footer": "Does anyone read our [Terms and Conditions](https://example.com) and [Privacy Policy](https://example.com)?"
              },
              "submit_button": {
                "text": "Add",
                "content_description": "Send a message to this email address"
              },
              "cancel_button": {
                "text": "Cancel"
              },
              "on_success": {
                "name": "Oh no, it worked.",
                "description": "Hope you like emails.",
                "button": {
                  "text": "Ok, dang"
                }
              },
              "error_messages": {
                "invalid": "Please enter a valid email address.",
                "default": "Uh oh, something went wrong."
              }
            }
          },
          "remove": {
            "button": {
              "text": "Opt out",
              "content_description": "Opt out and remove this email address"
            },
            "view": {
              "type": "prompt",
              "display": {
                "title": "Are you sure?",
                "body": "Detailed delete confirmation message about email goes here."
              },
              "submit_button": {
                "text": "Yes",
                "content_description": "Confirm opt out"
              },
              "cancel_button": {
                "text": "No",
                "content_description": "Cancel opt out"
              },
              "on_success": {
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
          "id": "sms-opt-in",
          "type": "contact_management",
          "platform": "sms",
          "empty_label": "No SMS added",
          "display": {
            "name": "Mobile Numbers",
            "description": "Mobile number lorem ipsum dolor sit amet, consectetur adipiscing elit."
          },
          "registration_options": {
            "type": "sms",
            "country_label": "Country",
            "msisdn_label": "Phone number",
            "resend": {
              "interval": 5,
              "message": "Pending verification",
              "button": {
                "text": "Resend",
                "content_description": "Resend a verification message to this phone number"
              },
              "on_success": {
                "name": "Verification resent",
                "description": "Check your messaging app for a new confirmation message.",
                "button": {
                  "text": "Ok",
                  "content_description": "Close prompt"
                }
              }
            },
            "senders": [
              {
                "country_code": "+1",
                "display_name": "United States",
                "placeholder_text": "18013623379",
                "sender_id": "18338647429"
              },
              {
                "country_code": "+44",
                "display_name": "United Kingdom",
                "placeholder_text": "2222 22222",
                "sender_id": "18338647429"
              },
              {
                "country_code": "+33",
                "display_name": "France",
                "placeholder_text": "3333 33333",
                "sender_id": "18338647429"
              },
              {
                "country_code": "+55",
                "display_name": "Brazil",
                "placeholder_text": "4444 44444",
                "sender_id": "18338647429"
              }
            ]
          },
          "add": {
            "view": {
              "type": "prompt",
              "display": {
                "title": "Add a phone number",
                "body": "You will receive a text message with further details.",
                "footer": "By opting in you give us the OK to [hound you forever](https://example.com)."
              },
              "submit_button": {
                "text": "Add",
                "content_description": "Send a message to this phone number"
              },
              "cancel_button": {
                "text": "Cancel"
              },
              "on_success": {
                "name": "Oh no, it worked.",
                "description": "Hope you like text messages.",
                "button": {
                  "text": "Ok, dang"
                }
              },
              "error_messages": {
                "invalid": "Please enter a valid phone number.",
                "default": "Uh oh, something went wrong."
              }
            },
            "button": {
              "text": "Add SMS",
              "content_description": "Add a new phone number"
            }
          },
          "remove": {
            "button": {
              "text": "Opt out",
              "content_description": "Opt out and remove this phone number"
            },
            "view": {
              "type": "prompt",
              "display": {
                "title": "Are you sure?",
                "body": "Detailed delete confirmation message about SMS goes here."
              },
              "submit_button": {
                "text": "Yes",
                "content_description": "Confirm opt out"
              },
              "cancel_button": {
                "text": "No",
                "content_description": "Cancel opt out"
              },
              "on_success": {
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

}


