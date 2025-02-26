/* Copyright Airship and Contributors */

import XCTest

@testable import AirshipCore

class FormStateTest: XCTestCase {

    @MainActor
    func testData() throws {
        let formState = ThomasFormState(
            identifier: "some-form-id",
            formType: .form,
            formResponseType: "user_feedback"
        )

        formState.updateFormInput(
            ThomasFormInput(
                "some-radio-input",
                value: .radio("some-radio-input-value"),
                isValid: true
            )
        )

        formState.updateFormInput(
            ThomasFormInput(
                "some-toggle-input",
                value: .toggle(true),
                isValid: true
            )
        )

        formState.updateFormInput(
            ThomasFormInput(
                "some-score-input",
                value: .score(7),
                isValid: true
            )
        )

        formState.updateFormInput(
            ThomasFormInput(
                "some-text-input",
                value: .text("neat text"),
                isValid: true
            )
        )

        // Child form data
        let childData = ThomasFormInput(
            "some-child-text-input",
            value: .text("some child text"),
            isValid: true
        )
        formState.updateFormInput(
            ThomasFormInput(
                "some-child-form",
                value: .form(responseType: "app_rating", children: [childData]),
                isValid: true
            )
        )

        // Child nps data
        let childScore = ThomasFormInput(
            "some-child-score",
            value: .score(8),
            isValid: true
        )
        formState.updateFormInput(
            ThomasFormInput(
                "some-child-nps",
                value: .npsForm(responseType: "nps", scoreID: "some-child-score", children: [childScore]),
                isValid: true
            )
        )

        let expected = [
            "some-form-id": [
                "type": "form",
                "response_type": "user_feedback",
                "children": [
                    "some-radio-input": [
                        "type": "single_choice",
                        "value": "some-radio-input-value",
                    ],
                    "some-toggle-input": [
                        "type": "toggle",
                        "value": true,
                    ] as [String: Any],
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
                        "response_type": "app_rating",
                        "children": [
                            "some-child-text-input": [
                                "type": "text_input",
                                "value": "some child text",
                            ]
                        ],
                    ] as [String : Any],
                    "some-child-nps": [
                        "type": "nps",
                        "score_id": "some-child-score",
                        "response_type": "nps",
                        "children": [
                            "some-child-score": [
                                "type": "score",
                                "value": 8,
                            ] as [String : Any]
                        ],
                    ],
                ],
            ] as [String : Any]
        ]

        XCTAssertEqual(
            try AirshipJSON.wrap(expected),
            formState.data.toPayload()
        )
    }

    @MainActor
    func testAttributes() throws {
        let formState = ThomasFormState(
            identifier: "some-form-id",
            formType: .form,
            formResponseType: "user_feedback"
        )

        formState.updateFormInput(
            ThomasFormInput(
                "some-input",
                value: .radio("some-radio-input-value"),
                attribute: .init(
                    attributeName: ThomasAttributeName(
                        channel: "some-input-channel-name",
                        contact: "some-input-contact-name"
                    ),
                    attributeValue: .number(10.0)
                ),
                isValid: true
            )
        )

        formState.updateFormInput(
            ThomasFormInput(
                "missing-attribute-value",
                value: .text("some child text"),
                isValid: true
            )
        )

        formState.updateFormInput(
            ThomasFormInput(
                "missing-attribute-name",
                value: .text("some child text"),
                isValid: true
            )
        )

        formState.updateFormInput(
            ThomasFormInput(
                "missing-attribute-name-and-value",
                value: .text("some child text"),
                isValid: true
            )
        )

        // Child form data
        let childData = ThomasFormInput(
            "some-child-input",
            value: .text("some child text"),
            attribute: .init(
                attributeName: ThomasAttributeName(
                    channel: "some-child-input-channel-name",
                    contact: "some-child-input-contact-name"
                ),
                attributeValue: .string("hello form")
            ),
            isValid: true
        )

        formState.updateFormInput(
            ThomasFormInput(
                "some-child-form",
                value: .form(responseType: "user_feedback", children: [childData]),
                isValid: true
            )
        )

        // Child nps data
        let childScore = ThomasFormInput(
            "some-child-score",
            value: .score(8),
            attribute: .init(
                attributeName: ThomasAttributeName(
                    channel: "some-nps-child-input-channel-name",
                    contact: "some-nps-child-input-contact-name"
                ),
                attributeValue: .string("hello nps")
            ),
            isValid: true
        )
        formState.updateFormInput(
            ThomasFormInput(
                "some-child-nps",
                value: .npsForm(responseType: "nps", scoreID: "some-child-score", children: [childScore]),
                isValid: true
            )
        )

        let expected: [(ThomasAttributeName, ThomasAttributeValue)] = [
            (
                ThomasAttributeName(
                    channel: "some-input-channel-name",
                    contact: "some-input-contact-name"
                ),
                .number(10.0)
            ),
            (
                ThomasAttributeName(
                    channel: "some-child-input-channel-name",
                    contact: "some-child-input-contact-name"
                ),
                .string("hello form")
            ),
            (
                ThomasAttributeName(
                    channel: "some-nps-child-input-channel-name",
                    contact: "some-nps-child-input-contact-name"
                ),
                .string("hello nps")
            ),
        ]

        let actual = formState.data.attributes
        XCTAssertEqual(expected.count, actual.count)
        expected.forEach { expectedEntry in
            XCTAssertTrue(
                actual.contains(where: {
                    $0.attributeName == expectedEntry.0 && $0.attributeValue == expectedEntry.1
                })
            )
        }
    }
}
