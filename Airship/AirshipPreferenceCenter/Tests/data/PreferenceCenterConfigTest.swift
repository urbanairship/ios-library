/* Copyright Airship and Contributors */

import AirshipCore
import XCTest

@testable import AirshipPreferenceCenter

class PreferenceCenterDecoderTest: XCTestCase {
    func testForm() throws {
        let testPayload: String = """
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
        let expected = PreferenceCenterConfig(
            identifier: "cool-prefs",
            sections: [
                .common(
                    PreferenceCenterConfig.CommonSection(
                        identifier: "opt-in",
                        items: [
                            .contactManagement(
                                PreferenceCenterConfig.ContactManagementItem(
                                    identifier: "email-opt-in",
                                    platform: .email,
                                    display: PreferenceCenterConfig.ContactManagementItem.CommonDisplay(
                                        title: "Email Addresses",
                                        subtitle: "Email address lorem ipsum dolor sit amet, consectetur adipiscing elit."
                                    ),
                                    emptyLabel: "No email added",
                                    addPrompt: PreferenceCenterConfig.ContactManagementItem.AddPrompt(
                                        view: PreferenceCenterConfig.ContactManagementItem.AddChannelPrompt(
                                            display: PreferenceCenterConfig.ContactManagementItem.PromptDisplay(
                                                title: "Add an email address",
                                                body: "You will receive a confirmation email to verify your address.",
                                                footer: "Does anyone read our [Terms and Conditions](https://example.com) and [Privacy Policy](https://example.com)?",
                                                errorMessage: "error message"
                                            ),
                                            onSuccess: PreferenceCenterConfig.ContactManagementItem.ActionableMessage(
                                                title: "Oh no, it worked.",
                                                body: "Hope you like emails.",
                                                button: PreferenceCenterConfig.ContactManagementItem.LabeledButton(text: "Ok, dang")
                                            ),
                                            errorMessages: PreferenceCenterConfig.ContactManagementItem.ErrorMessages(
                                                invalidMessage: "Please enter a valid email address.",
                                                defaultMessage: "Uh oh, something went wrong."
                                            ),
                                            cancelButton: PreferenceCenterConfig.ContactManagementItem.LabeledButton(text: "Cancel"),
                                            submitButton: PreferenceCenterConfig.ContactManagementItem.LabeledButton(text: "Add", contentDescription: "Send a message to this email address")
                                        ),
                                        button: PreferenceCenterConfig.ContactManagementItem.LabeledButton(text: "Add email", contentDescription: "Add a new email address")
                                    ),
                                    removePrompt: PreferenceCenterConfig.ContactManagementItem.RemoveChannel(
                                        view: PreferenceCenterConfig.ContactManagementItem.RemoveChannelPrompt(
                                            display: PreferenceCenterConfig.ContactManagementItem.PromptDisplay(
                                                title: "Are you sure?",
                                                body: "Detailed delete confirmation message about email goes here.",
                                                errorMessage: "error message"
                                            ),
                                            acceptButton: PreferenceCenterConfig.ContactManagementItem.LabeledButton(
                                                text: "Yes",
                                                contentDescription: "Confirm opt out"
                                            )
                                        ),
                                        button: PreferenceCenterConfig.ContactManagementItem.LabeledButton(text: "Opt out", contentDescription: "Opt out and remove this email address")
                                    ),
                                    registrationOptions: .email(
                                        PreferenceCenterConfig.ContactManagementItem.EmailRegistrationOption(
                                            placeholder: "example@domain.com",
                                            addressLabel: "Email address",
                                            pendingLabel: PreferenceCenterConfig.ContactManagementItem.PendingLabel(
                                                intervalInSeconds: 5,
                                                message: "Pending verification",
                                                button: PreferenceCenterConfig.ContactManagementItem.LabeledButton(
                                                    text: "Resend",
                                                    contentDescription: "Resend a verification message to this email address"
                                                ),
                                                resendSuccessPrompt: PreferenceCenterConfig.ContactManagementItem.ActionableMessage(
                                                    title: "Verification resent",
                                                    body: "Check your inbox for a new confirmation email.",
                                                    button: PreferenceCenterConfig.ContactManagementItem.LabeledButton(
                                                        text: "Ok",
                                                        contentDescription: "Close prompt"
                                                    )
                                                )
                                            )
                                        )
                                    ),
                                    conditions: []
                                )
                            ),
                            .contactManagement(
                                PreferenceCenterConfig.ContactManagementItem(
                                    identifier: "sms-opt-in",
                                    platform: .sms,
                                    display: PreferenceCenterConfig.ContactManagementItem.CommonDisplay(
                                        title: "Mobile Numbers",
                                        subtitle: "Mobile number lorem ipsum dolor sit amet, consectetur adipiscing elit."
                                    ),
                                    emptyLabel: "No SMS added",
                                    addPrompt: PreferenceCenterConfig.ContactManagementItem.AddPrompt(
                                        view: PreferenceCenterConfig.ContactManagementItem.AddChannelPrompt(
                                            display: PreferenceCenterConfig.ContactManagementItem.PromptDisplay(
                                                title: "Add a phone number",
                                                body: "You will receive a text message with further details.",
                                                footer: "By opting in you give us the OK to [hound you forever](https://example.com).",
                                                errorMessage: "error message"
                                            ),
                                            onSuccess: PreferenceCenterConfig.ContactManagementItem.ActionableMessage(
                                                title: "Oh no, it worked.",
                                                body: "Hope you like text messages.",
                                                button: PreferenceCenterConfig.ContactManagementItem.LabeledButton(text: "Ok, dang")
                                            ),
                                            errorMessages: PreferenceCenterConfig.ContactManagementItem.ErrorMessages(
                                                invalidMessage: "Please enter a valid phone number.",
                                                defaultMessage: "Uh oh, something went wrong."
                                            ),
                                            cancelButton: PreferenceCenterConfig.ContactManagementItem.LabeledButton(text: "Cancel"),
                                            submitButton: PreferenceCenterConfig.ContactManagementItem.LabeledButton(text: "Add", contentDescription: "Send a message to this phone number")
                                        ),
                                        button: PreferenceCenterConfig.ContactManagementItem.LabeledButton(text: "Add SMS", contentDescription: "Add a new phone number")
                                    ),
                                    removePrompt: PreferenceCenterConfig.ContactManagementItem.RemoveChannel(
                                        view: PreferenceCenterConfig.ContactManagementItem.RemoveChannelPrompt(
                                            display: PreferenceCenterConfig.ContactManagementItem.PromptDisplay(
                                                title: "Are you sure?",
                                                body: "Detailed delete confirmation message about SMS goes here.",
                                                errorMessage: "error message"
                                            ),
                                            acceptButton: PreferenceCenterConfig.ContactManagementItem.LabeledButton(
                                                text: "Yes",
                                                contentDescription: "Confirm opt out"
                                            )
                                        ),
                                        button: PreferenceCenterConfig.ContactManagementItem.LabeledButton(text: "Opt out", contentDescription: "Opt out and remove this phone number")
                                    ),

                                    registrationOptions: .sms(
                                        PreferenceCenterConfig.ContactManagementItem.SmsRegistrationOption(
                                            senders: [
                                                PreferenceCenterConfig.ContactManagementItem.SmsSenderInfo(
                                                    senderId: "14243696000",
                                                    placeholderText: "18013623379",
                                                    countryCode: "+1",
                                                    displayName: "United States"
                                                ),
                                                PreferenceCenterConfig.ContactManagementItem.SmsSenderInfo(
                                                    senderId: "2222",
                                                    placeholderText: "2222 22222",
                                                    countryCode: "+44",
                                                    displayName: "United Kingdom"
                                                ),
                                                PreferenceCenterConfig.ContactManagementItem.SmsSenderInfo(
                                                    senderId: "3333",
                                                    placeholderText: "3333 33333",
                                                    countryCode: "+33",
                                                    displayName: "France"
                                                ),
                                                PreferenceCenterConfig.ContactManagementItem.SmsSenderInfo(
                                                    senderId: "4444",
                                                    placeholderText: "4444 44444",
                                                    countryCode: "+55",
                                                    displayName: "Brazil"
                                                )
                                            ],
                                            countryLabel: "Country",
                                            msisdnLabel: "Phone number",
                                            pendingLabel: PreferenceCenterConfig.ContactManagementItem.PendingLabel(
                                                intervalInSeconds: 5,
                                                message: "Pending verification",
                                                button: PreferenceCenterConfig.ContactManagementItem.LabeledButton(text: "Resend", contentDescription: "Resend a verification message to this phone number"),
                                                resendSuccessPrompt: PreferenceCenterConfig.ContactManagementItem.ActionableMessage(
                                                    title: "Verification resent",
                                                    body: "Check your messaging app for a new confirmation message.",
                                                    button: PreferenceCenterConfig.ContactManagementItem.LabeledButton(text: "Ok", contentDescription: "Close prompt")
                                                )
                                            )
                                        )
                                    ),
                                    conditions: []
                                )
                            )
                        ]
                    )
                )
            ],
            display: PreferenceCenterConfig.CommonDisplay(
                title: "Cool Prefs",
                subtitle: "Preferences but they're cool"
            )
        )

        let response = try! PreferenceCenterDecoder.decodeConfig(
            data: testPayload.data(using: .utf8)!
        )

        do {
            let expectedJson = try expected.prettyPrintedJSON()
            let responseJson = try response.prettyPrintedJSON()

            let expected = parseAndSortJSON(jsonString: expectedJson)
            let response = parseAndSortJSON(jsonString: responseJson)

            XCTAssertEqual(expected, response)
        } catch {
            print("Error: \(error)")
            XCTFail()
        }
    }

    private func parseAndSortJSON(jsonString: String) -> String? {
        guard let data = jsonString.data(using: .utf8),
              let jsonObject = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
        else { return nil }

        let sortedData = try? JSONSerialization.data(withJSONObject: jsonObject, options: [.sortedKeys, .prettyPrinted])
        return sortedData.flatMap { String(data: $0, encoding: .utf8) }
    }
}

