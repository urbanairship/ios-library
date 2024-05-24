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
  "display" : {
    "description" : "Preferences but they're cool",
    "name" : "Cool Prefs"
  },
  "id" : "cool-prefs",
  "sections" : [
    {
      "items" : [
        {
          "id" : "email-opt-in",
          "display" : {
            "description" : "Email address lorem ipsum dolor sit amet, consectetur adipiscing elit.",
            "name" : "Email Addresses"
          },
          "remove" : {
            "button" : {
              "text" : "Opt out",
              "content_description" : "Opt out and remove this email address"
            },
            "view" : {
              "display" : {
                "error_message" : "error message",
                "body" : "Detailed delete confirmation message about email goes here.",
                "title" : "Are you sure?"
              },
              "submit_button" : {
                "content_description" : "Confirm opt out",
                "text" : "Yes"
              }
            }
          },
          "empty_label" : "No email added",
          "conditions" : [

          ],
          "add" : {
            "view" : {
              "submit_button" : {
                "text" : "Add",
                "content_description" : "Send a message to this email address"
              },
              "error_messages" : {
                "invalid" : "Please enter a valid email address.",
                "default" : "Uh oh, something went wrong."
              },
              "on_success" : {
                "name" : "Oh no, it worked.",
                "description" : "Hope you like emails.",
                "button" : {
                  "text" : "Ok, dang"
                }
              },
              "display" : {
                "error_message" : "error message",
                "title" : "Add an email address",
                "footer" : "Does anyone read our [Terms and Conditions](https://example.com) and [Privacy Policy](https://example.com)?",
                "body" : "You will receive a confirmation email to verify your address."
              },
              "cancel_button" : {
                "text" : "Cancel"
              }
            },
            "button" : {
              "content_description" : "Add a new email address",
              "text" : "Add email"
            }
          },
          "platform" : "email",
          "registration_options" : {
            "placeholder_text" : "example@domain.com",
            "address_label" : "Email address",
            "type" : "email",
            "resend" : {
              "button" : {
                "content_description" : "Resend a verification message to this email address",
                "text" : "Resend"
              },
              "message" : "Pending verification",
              "on_success" : {
                "name" : "Verification resent",
                "description" : "Check your inbox for a new confirmation email.",
                "button" : {
                  "text" : "Ok",
                  "content_description" : "Close prompt"
                }
              },
              "interval" : 5
            }
          },
          "type" : "contact_management"
        },
        {
          "registration_options" : {
            "resend" : {
              "button" : {
                "text" : "Resend",
                "content_description" : "Resend a verification message to this phone number"
              },
              "on_success" : {
                "name" : "Verification resent",
                "description" : "Check your messaging app for a new confirmation message.",
                "button" : {
                  "text" : "Ok",
                  "content_description" : "Close prompt"
                }
              },
              "interval" : 5,
              "message" : "Pending verification"
            },
            "senders" : [
              {
                "placeholder_text" : "18013623379",
                "country_code" : "+1",
                "sender_id" : "14243696000",
                "display_name" : "United States"
              },
              {
                "sender_id" : "2222",
                "country_code" : "+44",
                "display_name" : "United Kingdom",
                "placeholder_text" : "2222 22222"
              },
              {
                "placeholder_text" : "3333 33333",
                "display_name" : "France",
                "country_code" : "+33",
                "sender_id" : "3333"
              },
              {
                "sender_id" : "4444",
                "placeholder_text" : "4444 44444",
                "display_name" : "Brazil",
                "country_code" : "+55"
              }
            ],
            "country_label" : "Country",
            "msisdn_label" : "Phone number",
            "type" : "sms"
          },
          "display" : {
            "description" : "Mobile number lorem ipsum dolor sit amet, consectetur adipiscing elit.",
            "name" : "Mobile Numbers"
          },
          "type" : "contact_management",
          "platform" : "sms",
          "add" : {
            "view" : {
              "cancel_button" : {
                "text" : "Cancel"
              },
              "submit_button" : {
                "content_description" : "Send a message to this phone number",
                "text" : "Add"
              },
              "display" : {
                "error_message" : "error message",
                "footer" : "By opting in you give us the OK to [hound you forever](https://example.com).",
                "title" : "Add a phone number",
                "body" : "You will receive a text message with further details."
              },
              "on_success" : {
                "name" : "Oh no, it worked.",
                "description" : "Hope you like text messages.",
                "button" : {
                  "text" : "Ok, dang"
                }
              },
              "error_messages" : {
                "invalid" : "Please enter a valid phone number.",
                "default" : "Uh oh, something went wrong."
              }
            },
            "button" : {
              "text" : "Add SMS",
              "content_description" : "Add a new phone number"
            }
          },
          "empty_label" : "No SMS added",
          "conditions" : [

          ],
          "id" : "sms-opt-in",
          "remove" : {
            "view" : {
              "display" : {
                "body" : "Detailed delete confirmation message about SMS goes here.",
                "error_message" : "error message",
                "title" : "Are you sure?"
              },
              "submit_button" : {
                "text" : "Yes",
                "content_description" : "Confirm opt out"
              }
            },
            "button" : {
              "text" : "Opt out",
              "content_description" : "Opt out and remove this phone number"
            }
          }
        }
      ],
      "id" : "opt-in",
      "type" : "section"
    }
  ]
}
"""

}


