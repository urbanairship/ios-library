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
    "name": "Preference Center",
    "description": "Manage preferences and communications received from Southwest Airlines"
  },
  "sections": [
    {
      "id": "e2450430-728f-4cb3-8b29-b6b774573557",
      "type": "section",
      "items": [
        {
          "id": "dcaa0861-ac2a-4863-89e7-38daf07e6502",
          "type": "alert",
          "display": {
            "description": "You will not receive any notifications from Southwest Airlines.",
            "icon": "https://hangar-dl.urbanairship.com/binary/public/VWDwdOFjRTKLRxCeXTVP6g/f4b5d20a-f1fc-446e-8093-8d2d1a33bb67",
            "name": "Notifications are off"
          },
          "button": {
            "actions": {
              "enable_feature": "user_notifications"
            },
            "text": "Enable notifications",
            "content_description": "Opens the settings for your app."
          }
        }
      ],
      "conditions": [
        {
          "when_status": "opt_out",
          "type": "notification_opt_in"
        }
      ]
    },
    {
      "id": "opt-in",
      "type": "section",
      "items": [
        {
          "id": "dcaa0861-ac2a-4863-89e7-38daf07e6505",
          "type": "contact_management",
          "platform": "email",
          "empty_label": "No email added",
          "display": {
            "name": "Add Email Address",
            "description": "Enter your email address to opt in to receiving email messages from our team."
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
                "name": "Check your inbox!",
                "description": "To opt-in tap confirm in the email we just sent to your inbox.",
                "button": {
                  "text": "Close"
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
          "id": "dcaa0861-ac2a-4863-89e7-38daf07e6506",
          "type": "contact_management",
          "platform": "sms",
          "empty_label": "No SMS added",
          "display": {
            "name": "Add Phone Number",
            "description": "A list of phone numbers associated with your account."
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
                  "text": "Close",
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
                "sender_id": "183386474291"
              },
              {
                "country_code": "+33",
                "display_name": "France",
                "placeholder_text": "3333 33333",
                "sender_id": "183386474292"
              },
              {
                "country_code": "+55",
                "display_name": "Brazil",
                "placeholder_text": "4444 44444",
                "sender_id": "183386474293"
              }
            ]
          },
          "add": {
            "view": {
              "type": "prompt",
              "display": {
                "title": "Add a phone number",
                "body": "You will receive a text message with further details.",
                "footer": "By opting in you give us the OK to reach you: [privacy policy](https://example.com)."
              },
              "submit_button": {
                "text": "Add",
                "content_description": "Send a message to this phone number"
              },
              "cancel_button": {
                "text": "Cancel"
              },
              "on_success": {
                "name": "Check your message app!",
                "description": "To opt-in reply Y to the message we just texted you.",
                "button": {
                  "text": "OK"
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
    },
    {
      "id": "151e8b8c-ff56-48d0-b8bc-52d26b9baf6b",
      "type": "section",
      "items": [
        {
          "id": "bbe8479a-b79a-423e-a323-b8f3cd33ddeb",
          "type": "contact_subscription_group",
          "subscription_id": "cows",
          "components": [
            {
              "display": {
                "name": "Email"
              },
              "scopes": [
                "email"
              ]
            }
          ],
          "display": {
            "description": "Take advantage of our featured offers. When you book with Southwest, you'll save and earn Rapid Rewards® points when you travel.",
            "name": "Featured Offers"
          }
        },
        {
          "id": "e908d3c7-3382-45c5-87ff-54f042e43193",
          "type": "contact_subscription_group",
          "subscription_id": "my_list",
          "components": [
            {
              "scopes": [
                "app"
              ],
              "display": {
                "name": "App"
              }
            },
            {
              "display": {
                "name": "Email"
              },
              "scopes": [
                "email"
              ]
            },
            {
              "display": {
                "name": "SMS"
              },
              "scopes": [
                "sms"
              ]
            }
          ],
          "display": {
            "name": "Hotel Updates",
            "description": "Find hotels at Southwest Airlines. Get information on your stay including check-in time via Push, SMS or Email."
          }
        },
        {
          "id": "b7fb8812-fc05-4863-a1b4-e65ada83a6e1",
          "type": "contact_subscription_group",
          "subscription_id": "goats",
          "components": [
            {
              "display": {
                "name": "Email"
              },
              "scopes": [
                "email"
              ]
            }
          ],
          "display": {
            "description": "Find cheap flights and flight deals at Southwest Airlines. Learn about sale fares and sign up for emails to receive the latest news and promotions.",
            "name": "Special Offers and Deals on Flights"
          }
        }
      ]
    }
  ]
}
"""

}


