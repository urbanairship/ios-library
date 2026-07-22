/* Copyright Airship and Contributors */

import Testing
import Foundation

@testable import AirshipBasement
@testable @_spi(AirshipInternal) import AirshipSceneRenderer

@MainActor
struct ThomasFormPayloadGeneratorTest {

    @Test("Test form data")
    func testFormData() throws {
        let form: ThomasFormField.Value = .form(
                responseType: "user_feedback",
                children: [
                    "some-radio-input": .radio(AirshipJSON.string("some-radio-input-value")),
                    "some-toggle-input": .toggle(true),
                    "some-score-input": .score(7.0),
                    "some-text-input": .text("neat text", aiInference: nil),
                    "some-email-input": .email("email@email.email"),
                    "some-sms-input": .sms("123", nil),
                    "some-child-score": .score(8.0),
                    "some-child-form": .form(
                        responseType: "some-child-form-response",
                        children: [
                            "some-other-text-input": .text("other neat text", aiInference: nil)
                        ]
                    ),
                    "some-child-nps-form": .npsForm(
                        responseType: "some-nps-child-form-response",
                        scoreID: "some-other-child-score",
                        children: [
                            "some-other-child-score": .score(9.0)
                        ]
                    ),
                    "text-nil": .text(nil, aiInference: nil),
                    "email-nil": .email(nil),
                    "sms-nil": .sms(nil, .init(countryCode: "US", prefix: "+1")),
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
                "value": 7.0
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
                "value": 8.0
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
                    "some-text-input": .text("neat text", aiInference: nil),
                    "some-email-input": .email("email@email.email"),
                    "some-child-score": .score(8.0),
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
                formValue: .text("some-text", aiInference: nil)
            )
        }
    }

    @Test("ai_inference carried on the text value is emitted in the event payload")
    func testFormDataWithAIInference() throws {
        let report = ThomasAIInferenceReport.success(
            output: .object(["category": .string("goat_hater")])
        )
        let form: ThomasFormField.Value = .form(
            responseType: "user_feedback",
            children: [
                "question-id-1": .text("I hate goats", aiInference: report),
                "question-id-2": .score(7.0)
            ]
        )

        let expectedJSON = """
        {
          "some-form-id": {
            "type": "form",
            "response_type": "user_feedback",
            "children": {
              "question-id-1": {
                "type": "text_input",
                "value": "I hate goats",
                "ai_inference": { "result": "success", "output": { "category": "goat_hater" } }
              },
              "question-id-2": {
                "type": "score",
                "value": 7.0
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

    @Test("ai_inference on a text value is omitted from the state projection")
    func testStateProjectionOmitsAIInference() throws {
        let report = ThomasAIInferenceReport.success(
            output: .object(["category": .string("goat_hater")])
        )
        let field = ThomasFormField.validField(
            identifier: "question-id-1",
            input: .text("I hate goats", aiInference: nil),
            result: .init(value: .text("I hate goats", aiInference: report))
        )

        let payload = ThomasFormPayloadGenerator.makeFormStatePayload(
            status: .valid,
            fields: [field],
            formType: .form
        )
        // Neither the field value nor status.result should carry ai_inference.
        let data = try JSONEncoder().encode(payload)
        let json = String(decoding: data, as: UTF8.self)
        #expect(!json.contains("ai_inference"))
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
        let errorField = ThomasFormField.asyncField(
            identifier: "some-async-id",
            input: .score(7.0),
            processDelay: 0
        ) { .error }
        await errorField.process() // gets the error

        let pendingField = ThomasFormField.asyncField(
            identifier: "some-pending-async-id",
            input: .score(7.0),
            processDelay: 100.0
        ) { .invalid }

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

@MainActor
struct ThomasAIInferenceReportTest {

    private func schema(_ json: String) throws -> AirshipJSONSchema {
        try JSONDecoder().decode(AirshipJSONSchema.self, from: Data(json.utf8))
    }

    @Test("A value is reported only when it and every ancestor container are flagged")
    func testFilterRequiresFlaggedPath() throws {
        let schema = try schema("""
        {
          "type": "object",
          "x-ua-report-property": true,
          "properties": {
            "category": { "type": "string", "x-ua-report-property": true },
            "sentiment": { "type": "string" },
            "user": {
              "type": "object",
              "x-ua-report-property": true,
              "properties": {
                "name": { "type": "string" },
                "id": { "type": "string", "x-ua-report-property": true }
              }
            }
          }
        }
        """)

        let output = try AirshipJSON.from(json: """
        { "category": "goat_hater", "sentiment": "negative", "user": { "name": "Bob", "id": "42" } }
        """)

        // Root + `category` flagged -> kept. `sentiment` unflagged -> stripped. `user` flagged,
        // so its flagged `id` survives (whole path flagged) but unflagged `name` is stripped.
        let expected = try AirshipJSON.from(json: """
        { "category": "goat_hater", "user": { "id": "42" } }
        """)

        #expect(ThomasAIInferenceReport.reportedOutput(output, schema: schema) == expected)
    }

    @Test("An unflagged container prunes its whole subtree, even flagged children")
    func testFilterUnflaggedParentPrunesFlaggedChild() throws {
        let schema = try schema("""
        {
          "type": "object",
          "x-ua-report-property": true,
          "properties": {
            "user": {
              "type": "object",
              "properties": { "id": { "type": "string", "x-ua-report-property": true } }
            }
          }
        }
        """)
        // `user` is unflagged, so its flagged `id` is not reported and the whole thing is nil.
        let output = try AirshipJSON.from(json: #"{ "user": { "id": "42" } }"#)
        #expect(ThomasAIInferenceReport.reportedOutput(output, schema: schema) == nil)
    }

    @Test("Unflagged root reports nothing even with flagged children")
    func testFilterUnflaggedRootReportsNothing() throws {
        let schema = try schema("""
        {
          "type": "object",
          "properties": { "category": { "type": "string", "x-ua-report-property": true } }
        }
        """)
        let output = try AirshipJSON.from(json: #"{ "category": "goat_hater" }"#)
        #expect(ThomasAIInferenceReport.reportedOutput(output, schema: schema) == nil)
    }

    @Test("Array elements are reported when the array and its items are flagged")
    func testFilterFlaggedArrayItems() throws {
        let schema = try schema("""
        {
          "type": "object",
          "x-ua-report-property": true,
          "properties": {
            "tags": {
              "type": "array",
              "x-ua-report-property": true,
              "items": { "type": "string", "x-ua-report-property": true }
            }
          }
        }
        """)
        let output = try AirshipJSON.from(json: #"{ "tags": ["a", "b"] }"#)
        let expected = try AirshipJSON.from(json: #"{ "tags": ["a", "b"] }"#)
        #expect(ThomasAIInferenceReport.reportedOutput(output, schema: schema) == expected)
    }

    @Test("init prunes the output; nil when nothing is flagged; encodes without an output key")
    func testSuccessReport() throws {
        let flagged = try schema("""
        {
          "type": "object",
          "x-ua-report-property": true,
          "properties": { "category": { "type": "string", "x-ua-report-property": true } }
        }
        """)
        let output = try AirshipJSON.from(json: #"{ "category": "goat_hater" }"#)

        let report = ThomasAIInferenceReport(output: output, schema: flagged)
        #expect(report == .success(output: try AirshipJSON.from(json: #"{ "category": "goat_hater" }"#)))
        // Round-trips through Codable to the expected wire shape.
        #expect(try AirshipJSON.wrap(report) == (try AirshipJSON.from(json: """
        { "result": "success", "output": { "category": "goat_hater" } }
        """)))

        // Nothing on a flagged path -> success with no output; the output key is omitted.
        let unflagged = try schema(#"{ "type": "object", "properties": { "category": { "type": "string" } } }"#)
        #expect(ThomasAIInferenceReport(output: output, schema: unflagged) == .success(output: nil))
        #expect(try AirshipJSON.wrap(ThomasAIInferenceReport(output: output, schema: unflagged)) == .object(["result": .string("success")]))

        // No schema -> success with no output.
        #expect(ThomasAIInferenceReport(output: output, schema: nil) == .success(output: nil))
    }

    @Test("failed report is result:failed with no output")
    func testFailedReport() throws {
        #expect(try AirshipJSON.wrap(ThomasAIInferenceReport.failed) == .object(["result": .string("failed")]))
    }

}
