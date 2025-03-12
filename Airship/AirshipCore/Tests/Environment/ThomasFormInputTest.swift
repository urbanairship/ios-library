/* Copyright Airship and Contributors */

import Testing
@testable import AirshipCore

@MainActor
struct ThomasFormInputTest {

    @Test("Test form data")
    func testFormData() throws {
        let form = ThomasFormInput(
            "some-form-id",
            value: .form(
                responseType: "user_feedback",
                children: [
                    ThomasFormInput(
                        "some-radio-input",
                        value: .radio("some-radio-input-value")
                    ),
                    ThomasFormInput(
                        "some-toggle-input",
                        value: .toggle(true)
                    ),
                    ThomasFormInput(
                        "some-score-input",
                        value: .score(7)
                    ),
                    ThomasFormInput(
                        "some-text-input",
                        value: .text("neat text")
                    ),
                    ThomasFormInput(
                        "some-child-score",
                        value: .score(8)
                    )
                ]
            )
        )

        let expected: String = """
        {
          "some-form-id": {
            "type": "form",
            "response_type": "user_feedback",
            "children": {
              "some-radio-input": {
                "type": "single_choice",
                "value": "some-radio-input-value"
              },
              "some-toggle-input": {
                "type": "toggle",
                "value": true
              },
              "some-score-input": {
                "type": "score",
                "value": 7
              },
              "some-text-input": {
                "type": "text_input",
                "value": "neat text"
              },
              "some-child-score": {
                "type": "score",
                "value": 8
              }
            }
          }
        }
        """

        #expect(form.toPayload() == (try! AirshipJSON.from(json: expected)))
    }

    @Test("Test child form data")
    func testFormDataChildForm() throws {
        let form = ThomasFormInput(
            "some-form-id",
            value: .form(
                responseType: "user_feedback",
                children: [
                    ThomasFormInput(
                        "child-form",
                        value: .form(
                            responseType: "some-child-form-response",
                            children: [
                                ThomasFormInput(
                                    "some-text-input",
                                    value: .text("neat text")
                                ),
                            ]
                        )
                    ),
                    ThomasFormInput(
                        "child-nps-form",
                        value: .npsForm(
                            responseType: "some-nps-child-form-response",
                            scoreID: "some-child-score",
                            children: [
                                ThomasFormInput(
                                    "some-child-score",
                                    value: .score(8)
                                )
                            ]
                        )
                    )
                ]
            )
        )

        let expected: String = """
        {
          "some-form-id": {
            "type": "form",
            "response_type": "user_feedback",
            "children": {
              "child-form": {
                "type": "form",
                "response_type": "some-child-form-response",
                "children": {
                  "some-text-input": {
                    "type": "text_input",
                    "value": "neat text"
                  }
                }
              },
              "child-nps-form": {
                "type": "nps",
                "response_type": "some-nps-child-form-response",
                "score_id": "some-child-score",
                "children": {
                  "some-child-score": {
                    "type": "score",
                    "value": 8
                  }
                }
              }
            }
          }
        }

        """

        #expect(form.toPayload() == (try! AirshipJSON.from(json: expected)))
    }

    @Test("Test attributes")
    func testAttributes() throws {
        let form = ThomasFormInput(
            "some-form-id",
            value: .form(
                responseType: "user_feedback",
                children: [
                    ThomasFormInput(
                        "child-form",
                        value: .form(
                            responseType: "some-child-form-response",
                            children: [
                                ThomasFormInput(
                                    "some-text-input",
                                    value: .text("neat text"),
                                    attribute: .init(
                                        attributeName: .init(channel: "some-channel-name"),
                                        attributeValue: .string("some-string")
                                    )
                                ),
                            ]
                        )
                    )
                ]
            ),
            attribute: .init(
                attributeName: .init(contact: "some-contact-name"),
                attributeValue: .number(3)
            )
        )

        let expected: [ThomasFormInput.Attribute] = [
            .init(
                attributeName: .init(contact: "some-contact-name"),
                attributeValue: .number(3)
            ),
            .init(
                attributeName: .init(channel: "some-channel-name"),
                attributeValue: .string("some-string")
            )
        ]

        #expect(form.attributes == expected)
    }
}
