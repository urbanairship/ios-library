/* Copyright Airship and Contributors */

import XCTest
@testable
import AirshipCore

class FormStateTest: XCTestCase {

    func testData() throws {
        let formState = FormState(reducer: { children in
            return FormInputData("some-form-id",
                                 value: .form(children),
                                 isValid: true)
        })
        
        formState.updateFormInput(FormInputData("some-radio-input",
                                                value: .radio("some-radio-input-value"),
                                                isValid: true))
        
        formState.updateFormInput(FormInputData("some-toggle-input",
                                                value: .toggle("some-toggle-input-value"),
                                                isValid: true))
        
        formState.updateFormInput(FormInputData("some-score-input",
                                                value: .score(7),
                                                isValid: true))
        
        formState.updateFormInput(FormInputData("some-text-input",
                                                value: .text("neat text"),
                                                isValid: true))
        
        // Child form data
        let childData = FormInputData("some-child-text-input",
                                      value: .text("some child text"),
                                      isValid: true)
        formState.updateFormInput(FormInputData("some-child-form",
                                                value: .form([childData]),
                                                isValid: true))
        
        // Child nps data
        let childScore = FormInputData("some-child-score",
                                      value: .score(8),
                                      isValid: true)
        formState.updateFormInput(FormInputData("some-child-nps",
                                                value: .nps("some-child-score", [childScore]),
                                                isValid: true))
        
        
        let expected = [
            "some-form-id": [
                "type": "form",
                "children": [
                    "some-radio-input": [
                        "type": "single_choice",
                        "value": "some-radio-input-value",
                    ],
                    "some-toggle-input": [
                        "type": "toggle",
                        "value": "some-toggle-input-value",
                    ],
                    "some-score-input": [
                        "type": "score",
                        "value": 7,
                    ],
                    "some-text-input": [
                        "type": "text_input",
                        "value": "neat text",
                    ],
                    "some-child-form": [
                        "type": "form",
                        "children": [
                            "some-child-text-input": [
                                "type": "text_input",
                                "value": "some child text",
                            ]
                        ],
                    ],
                    "some-child-nps": [
                        "type": "nps",
                        "score_id": "some-child-score",
                        "children": [
                            "some-child-score": [
                                "type": "score",
                                "value": 8,
                            ]
                        ]
                    ]
                ]
            ]
        ]
        
        XCTAssertEqual(expected as NSDictionary, formState.data.toPayload()! as NSDictionary)
    }

    func testAttributes() throws {
        let formState = FormState(reducer: { children in
            return FormInputData("some-form-id",
                                 value: .form(children),
                                 isValid: true)
        })
        
        formState.updateFormInput(FormInputData("some-input",
                                                value: .radio("some-radio-input-value"),
                                                attributeName: AttributeName(channel: "some-input-channel-name", contact: "some-input-contact-name"),
                                                attributeValue: .number(10.0),
                                                isValid: true))
        
        formState.updateFormInput(FormInputData("missing-attribute-value",
                                                value: .text("some child text"),
                                                attributeName: AttributeName(channel: "missing", contact: "missing"),
                                                isValid: true))
        
        formState.updateFormInput(FormInputData("missing-attribute-name",
                                                value: .text("some child text"),
                                                attributeValue: .string("missing"),
                                                isValid: true))
        
        formState.updateFormInput(FormInputData("missing-attribute-name-and-value",
                                                value: .text("some child text"),
                                                isValid: true))
        
        // Child form data
        let childData = FormInputData("some-child-input",
                                      value: .text("some child text"),
                                      attributeName: AttributeName(channel: "some-child-input-channel-name", contact: "some-child-input-contact-name"),
                                      attributeValue: .string("hello form"),
                                      isValid: true)
        
        formState.updateFormInput(FormInputData("some-child-form",
                                                value: .form([childData]),
                                                isValid: true))
        
        // Child nps data
        let childScore = FormInputData("some-child-score",
                                      value: .score(8),
                                       attributeName: AttributeName(channel: "some-nps-child-input-channel-name", contact: "some-nps-child-input-contact-name"),
                                       attributeValue: .string("hello nps"),
                                      isValid: true)
        formState.updateFormInput(FormInputData("some-child-nps",
                                                value: .nps("some-child-score", [childScore]),
                                                isValid: true))
     
        let expected: [(AttributeName, AttributeValue)] = [
            (
                AttributeName(channel: "some-input-channel-name", contact: "some-input-contact-name"),
                .number(10.0)
            ),
            (
                AttributeName(channel: "some-child-input-channel-name", contact: "some-child-input-contact-name"),
                .string("hello form")
            ),
            (
                AttributeName(channel: "some-nps-child-input-channel-name", contact: "some-nps-child-input-contact-name"),
                .string("hello nps")
            )
        ]
        
        let actual = formState.data.attributes()
        XCTAssertEqual(expected.count, actual.count)        
        expected.forEach { expectedEntry in
            XCTAssertTrue(actual.contains(where: { $0.0 == expectedEntry.0 && $0.1 == expectedEntry.1 }))
        }
    }
}
