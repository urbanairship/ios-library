/* Copyright Airship and Contributors */

import Testing
import Foundation

@testable import AirshipCore

@MainActor
struct ThomasFormPayloadGeneratorTest {

    @Test("Test form data")
    func testFormData() throws {
        let form: ThomasFormField.Value = .form(
                responseType: "user_feedback",
                children: [
                    "some-radio-input": .radio("some-radio-input-value"),
                    "some-toggle-input": .toggle(true),
                    "some-score-input": .score(7),
                    "some-text-input": .text("neat text"),
                    "some-email-input": .email("email@email.email"),
                    "some-sms-input": .sms("123"),
                    "some-child-score": .score(8),
                    "some-child-form": .form(
                        responseType: "some-child-form-response",
                        children: [
                            "some-other-text-input": .text("other neat text")
                        ]
                    ),
                    "some-child-nps-form": .npsForm(
                        responseType: "some-nps-child-form-response",
                        scoreID: "some-other-child-score",
                        children: [
                            "some-other-child-score": .score(9)
                        ]
                    ),
                    "text-nil": .text(nil),
                    "email-nil": .email(nil),
                    "sms-nil": .sms(nil),
                    "score-nil": .score(nil),
                    "radio-nil": .radio(nil)
                ]
        )

        let expectedJSON: String = """
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
              "some-email-input": {
                "type": "email_input",
                "value": "email@email.email"
              },
              "some-sms-input": {
                "type": "sms_input",
                "value": "123"
              },
              "some-child-score": {
                "type": "score",
                "value": 8
              },
              "text-nil": {
                "type": "text_input"
              },
              "email-nil": {
                "type": "email_input"
              },
              "sms-nil": {
                "type": "sms_input"
              },
              "score-nil": {
                "type": "score"
              },
              "radio-nil": {
                "type": "single_choice"
              },
              "some-child-form": {
                "type": "form",
                "response_type": "some-child-form-response",
                "children": {
                  "some-other-text-input": {
                    "type": "text_input",
                    "value": "other neat text"
                  }
                }
              },
              "some-child-nps-form": {
                "type": "nps",
                "response_type": "some-nps-child-form-response",
                "score_id": "some-other-child-score",
                "children": {
                  "some-other-child-score": {
                    "type": "score",
                    "value": 9
                  }
                }
              }
            }
          }
        }
        """

        let expected = try AirshipJSON.from(json: expectedJSON)
        let actual = try ThomasFormPayloadGenerator.makeFormEventPayload(
            identifier: "some-form-id",
            formValue: form
        )
        #expect(actual == expected)
    }

    @Test("Test nps form data")
    func testNPSFormData() throws {
        let npsForm: ThomasFormField.Value = .npsForm(
                responseType: "user_feedback",
                scoreID: "some-child-score",
                children: [
                    "some-text-input": .text("neat text"),
                    "some-email-input": .email("email@email.email"),
                    "some-child-score": .score(8),
                ]
        )

        let expectedJSON: String = """
        {
          "some-form-id": {
            "type": "nps",
            "score_id": "some-child-score",
            "response_type": "user_feedback",
            "children": {
              "some-child-score": {
                "type": "score",
                "value": 8
              },
              "some-text-input": {
                "type": "text_input",
                "value": "neat text"
              },
              "some-email-input": {
                "type": "email_input",
                "value": "email@email.email"
              }
            }
          }
        }
        """

        let expected = try AirshipJSON.from(json: expectedJSON)
        let actual = try ThomasFormPayloadGenerator.makeFormEventPayload(
            identifier: "some-form-id",
            formValue: npsForm
        )
        #expect(actual == expected)
    }

    @Test("Test passing other values throws")
    func testFormDataThrows() throws {
        #expect(throws: NSError.self) {
            try ThomasFormPayloadGenerator.makeFormEventPayload(
                identifier: "some-form-id",
                formValue: .text("some-text")
            )
        }
    }

    @Test(
        "Test state data",
        arguments: [
            ThomasFormState.Status.valid,
            ThomasFormState.Status.invalid,
            ThomasFormState.Status.error,
            ThomasFormState.Status.pendingValidation,
            ThomasFormState.Status.submitted,
            ThomasFormState.Status.validating
        ]
    )
    func testStateData(formStatus: ThomasFormState.Status) async throws {
        let errorField = ThomasFormField.asyncField(identifier: "some-async-id", input: .score(7), processDelay: 0) { .error }
        await errorField.process() // gets the error

        let pendingField = ThomasFormField.asyncField(identifier: "some-pending-async-id", input: .score(7), processDelay: 100.0) { .invalid }

        let fields: [ThomasFormField] = [
            ThomasFormField.invalidField(identifier: "some-invalid-id", input: .email("neat")),
            ThomasFormField.validField(identifier: "some-valid-id", input: .email("neat"), result: .init(value: .email("actual"))),
            errorField,
            pendingField
        ]

        let expectedJSON = """
        {
           "data":{
              "children":{
                 "some-valid-id":{
                    "value":"neat",
                    "type":"email_input",
                    "status":{
                       "result":{
                          "value":"actual",
                          "type":"email_input"
                       },
                       "type":"valid"
                    }
                 },
                 "some-invalid-id":{
                    "status":{
                       "type":"invalid"
                    },
                    "value":"neat",
                    "type":"email_input"
                 },
                 "some-async-id":{
                    "value":7,
                    "status":{
                       "type":"error"
                    },
                    "type":"score"
                 },
                 "some-pending-async-id":{
                    "type":"score",
                    "value":7,
                    "status":{
                       "type":"pending"
                    }
                 }
              },
              "type": "form"
           },
           "status":{
              "type": "\(formStatus.rawValue)"
           }
        }
        """


        let expected = try AirshipJSON.from(json: expectedJSON)
        let actual = ThomasFormPayloadGenerator.makeFormStatePayload(
            status: formStatus,
            fields: fields,
            formType: .form
        )
        #expect(actual == expected)

    }
}
