/* Copyright Airship and Contributors */

import Testing
import Foundation

@testable import AirshipCore

@MainActor
struct ThomasFormStateTest {

    @Test("Test empty form")
    func testEmptyForm() async throws {
        let form = ThomasFormState(
            identifier: "some-form-id",
            formType: .form,
            formResponseType: "response type",
            validationMode: .immediate
        )

        #expect(form.identifier ==  "some-form-id")
        #expect(form.formType == .form)
        #expect(form.formResponseType == "response type")
        #expect(form.validationMode == .immediate)

        #expect(form.status == .invalid)
        #expect(form.isFormInputEnabled == true)
        #expect(form.isEnabled == true)
        #expect(form.isVisible == false)
        #expect(form.activeFields.isEmpty == true)
    }

    @Test("Test empty nps form")
    func testEmptyNPSForm() async throws {
        let form = ThomasFormState(
            identifier: "some-form-id",
            formType: .nps("score-id"),
            formResponseType: "response type",
            validationMode: .immediate
        )

        #expect(form.identifier ==  "some-form-id")
        #expect(form.formType == .nps("score-id"))
        #expect(form.formResponseType == "response type")
        #expect(form.validationMode == .immediate)

        #expect(form.status == .invalid)
        #expect(form.isFormInputEnabled == true)
        #expect(form.isEnabled == true)
        #expect(form.isVisible == false)
        #expect(form.activeFields.isEmpty == true)
    }

    @Test("Test empty form with on demand validation")
    func testEmptyFormOnDemandValidation() async throws {
        let form = ThomasFormState(
            identifier: "some-form-id",
            formType: .form,
            formResponseType: "response type",
            validationMode: .onDemand
        )

        #expect(form.identifier ==  "some-form-id")
        #expect(form.formType == .form)
        #expect(form.formResponseType == "response type")
        #expect(form.validationMode == .onDemand)

        #expect(form.status == .pendingValidation)
        #expect(form.isFormInputEnabled == true)
        #expect(form.isEnabled == true)
        #expect(form.isVisible == false)
        #expect(form.activeFields.isEmpty == true)
    }

    @Test("Test empty form submit")
    func testEmptyFormSubmit() async throws {
        let form = ThomasFormState(
            identifier: "some-form-id",
            formType: .form,
            formResponseType: "response type",
            validationMode: .onDemand
        )
        form.onSubmit = { _, _, _ in }

        await #expect(throws: NSError.self) {
            try await form.submit(layoutState: .empty)
        }
    }

    @Test("Test submit empty data throws.")
    func testInvalidFormSubmit() async throws {
        let form = ThomasFormState(
            identifier: "some-form-id",
            formType: .form,
            formResponseType: "response type",
            validationMode: .onDemand
        )
        form.onSubmit = { _, _, _ in }

        form.updateField(.invalidField(identifier: "some-id", input: .email(nil)))

        await #expect(throws: NSError.self) {
            try await form.submit(layoutState: .empty)
        }
    }

    @Test("Test update field predicate does not apply")
    func testSubmitSingleFilteredField() async throws {
        let form = ThomasFormState(
            identifier: "some-form-id",
            formType: .form,
            formResponseType: "response type",
            validationMode: .onDemand
        )
        form.onSubmit = { _, _, _ in }

        form.updateField(
            .validField(identifier: "some-id", input: .email(nil), result: .init(value: .email("valid email")))
        ) {
            false
        }

        await #expect(throws: NSError.self) {
            try await form.submit(layoutState: .empty)
        }
    }

    @Test("Test submit.")
    func testSubmit() async throws {
        let form = ThomasFormState(
            identifier: "some-form-id",
            formType: .form,
            formResponseType: "response type",
            validationMode: .onDemand
        )

        let field: ThomasFormField = .validField(
            identifier: "some-id",
            input: .email(nil),
            result: .init(
                value: .email("valid email"),
                channels: [
                    .email("some email", .doubleOptIn(.init()))
                ],
                attributes: [
                    .init(
                        attributeName: .init(channel: "some-id"),
                        attributeValue: .string("some value")
                    )
                ]
            )
        )

        let anotherField: ThomasFormField = .validField(
            identifier: "some-other-id",
            input: .email(nil),
            result: .init(
                value: .email("other valid email"),
                channels: [
                    .email("some other email", .doubleOptIn(.init()))
                ],
                attributes: [
                    .init(
                        attributeName: .init(channel: "some-id"),
                        attributeValue: .string("some other value")
                    )
                ]
            )
        )

        form.updateField(field)
        form.updateField(anotherField)
        #expect(form.activeFields.count == 2)

        try await confirmation { confirmation in
            form.onSubmit = { id, result, _ in
                let expectedResult: ThomasFormField.Result = .init(
                    value: .form(
                        responseType: form.formResponseType,
                        children: [
                            "some-other-id": .email("other valid email"),
                            "some-id": .email("valid email"),
                        ]
                    ),
                    channels: field.channels + anotherField.channels,
                    attributes: field.attributes + anotherField.attributes
                )

                #expect(id == "some-form-id")
                #expect(result == expectedResult)

                confirmation.confirm()
            }

            try await form.submit(layoutState: .empty)
        }
    }

    @Test("Test submit checks predicate")
    func testSubmitChecksPredicate() async throws {
        let screen = AirshipMainActorValue("foo")

        let form = ThomasFormState(
            identifier: "some-form-id",
            formType: .form,
            formResponseType: "response type",
            validationMode: .onDemand
        )

        let fooField: ThomasFormField = .validField(
            identifier: "foo-id",
            input: .email(nil),
            result: .init(
                value: .email("foo"),
                channels: [
                    .email("some email", .doubleOptIn(.init()))
                ],
                attributes: [
                    .init(
                        attributeName: .init(channel: "some-id"),
                        attributeValue: .string("some value")
                    )
                ]
            )
        )

        let barField: ThomasFormField = .validField(
            identifier: "bar-id",
            input: .email(nil),
            result: .init(
                value: .email("bar"),
                channels: [
                    .email("some other email", .doubleOptIn(.init()))
                ],
                attributes: [
                    .init(
                        attributeName: .init(channel: "some-id"),
                        attributeValue: .string("some other value")
                    )
                ]
            )
        )

        form.updateField(fooField) {
            screen.value == "foo"
        }
        #expect(form.activeFields.count == 1)

        form.updateField(barField) {
            screen.value == "bar"
        }
        #expect(form.activeFields.count == 1)

        screen.update { $0 = "bar" }

        try await confirmation { confirmation in
            form.onSubmit = { id, result, _ in
                let expectedResult: ThomasFormField.Result = .init(
                    value: .form(
                        responseType: form.formResponseType,
                        children: [
                            "bar-id": .email("bar"),
                        ]
                    ),
                    channels: barField.channels,
                    attributes: barField.attributes
                )

                #expect(id == "some-form-id")
                #expect(result == expectedResult)

                confirmation.confirm()
            }

            try await form.submit(layoutState: .empty)
        }
    }

    @Test("Test data change for onDemand mode.")
    func testDataChangeOnDemand() async throws {
        let screen = AirshipMainActorValue("foo")

        let form = ThomasFormState(
            identifier: "some-form-id",
            formType: .form,
            formResponseType: "response type",
            validationMode: .onDemand
        )

        var updates = form.statusUpdates.makeAsyncIterator()

        await #expect(updates.next() == .pendingValidation)

        print("start")

        let fooField: ThomasFormField = .validField(
            identifier: "foo-id",
            input: .email(nil),
            result: .init(
                value: .email("foo")
            )
        )

        let barField: ThomasFormField = .invalidField(
            identifier: "bar-id",
            input: .email(nil)
        )

        form.updateField(fooField) {
            screen.value == "foo"
        }
        #expect(form.activeFields.count == 1)

        form.updateField(barField) {
            screen.value == "bar"
        }
        #expect(form.activeFields.count == 1)

        await #expect(form.validate() == true)
        await #expect(updates.next() == .validating)
        await #expect(updates.next() == .valid)

        screen.update { $0 = "bar" }
        form.dataChanged()

        await #expect(form.validate() == false)
        await #expect(updates.next() == .pendingValidation)
        await #expect(updates.next() == .validating)
        await #expect(updates.next() == .invalid)

        screen.update { $0 = "foo" }
        form.dataChanged()

        await #expect(updates.next() == .valid)

        await #expect(form.validate() == true)
        await #expect(updates.next() == .validating)
        await #expect(updates.next() == .valid)

        form.updateField(
            .asyncField(
                identifier: "bar-id",
                input: .score(AirshipJSON.number(2.0)),
                processDelay: 0.1
            ) {
                .valid(.init(value: .score(AirshipJSON.number(1.0))))
            }
        ) {
            screen.value == "bar"
        }

        await #expect(form.validate() == true)
        await #expect(updates.next() == .validating)
        await #expect(updates.next() == .valid)

        screen.update { $0 = "bar" }
        form.dataChanged()
        await #expect(updates.next() == .pendingValidation)
    }

    @Test("Test data change for immediate mode.")
    func testDataChangeImmediate() async throws {
        let screen = AirshipMainActorValue("foo")

        let form = ThomasFormState(
            identifier: "some-form-id",
            formType: .form,
            formResponseType: "response type",
            validationMode: .immediate
        )

        var updates = form.statusUpdates.makeAsyncIterator()
        await #expect(updates.next() == .invalid)

        let fooField: ThomasFormField = .validField(
            identifier: "foo-id",
            input: .email(nil),
            result: .init(
                value: .email("foo")
            )
        )

        let barField: ThomasFormField = .invalidField(
            identifier: "bar-id",
            input: .email(nil)
        )

        form.updateField(barField) {
            screen.value == "bar"
        }

        await #expect(updates.next() == .valid)

        form.updateField(fooField) {
            screen.value == "foo"
        }

        #expect(form.activeFields.count == 1)
        await #expect(updates.next() == .pendingValidation)
        await #expect(updates.next() == .validating)
        await #expect(updates.next() == .valid)

        await #expect(form.validate() == true)
        await #expect(updates.next() == .validating)
        await #expect(updates.next() == .valid)

        screen.update { $0 = "bar" }
        form.dataChanged()
        await #expect(updates.next() == .pendingValidation)
        await #expect(updates.next() == .validating)
        await #expect(updates.next() == .invalid)

        await #expect(form.validate() == false)
        await #expect(updates.next() == .validating)
        await #expect(updates.next() == .invalid)

        screen.update { $0 = "foo" }
        form.dataChanged()

        await #expect(updates.next() == .valid)

        await #expect(form.validate() == true)
        await #expect(updates.next() == .validating)
        await #expect(updates.next() == .valid)

        form.updateField(
            .asyncField(
                identifier: "bar-id",
                input: .score(AirshipJSON.number(2.0)),
                processDelay: 0.1
            ) {
                .valid(.init(value: .score(AirshipJSON.number(1.0))))
            }
        ) {
            screen.value == "bar"
        }

        await #expect(form.validate() == true)
        await #expect(updates.next() == .validating)
        await #expect(updates.next() == .valid)

        screen.update { $0 = "bar" }
        form.dataChanged()
        await #expect(updates.next() == .pendingValidation)
    }

    @Test("Test updating fields on demand")
    func testUpdateFieldsOnDemand() async throws {
        let form = ThomasFormState(
            identifier: "some-form-id",
            formType: .form,
            formResponseType: "response type",
            validationMode: .onDemand
        )

        var updates = form.statusUpdates.makeAsyncIterator()

        await #expect(updates.next() == .pendingValidation)

        form.updateField(.validField(identifier: "some-valid-id", input: .score(AirshipJSON.number(1.0)), result: .init(value: .score(AirshipJSON.number(1.0)))))
        #expect(form.status == .pendingValidation)

        form.updateField(.invalidField(identifier: "some-id", input: .score(AirshipJSON.number(1.0))))
        #expect(form.status == .pendingValidation)

        form.updateField(.invalidField(identifier: "some-other-id", input: .score(AirshipJSON.number(2.0))))
        #expect(form.status == .pendingValidation)

        await #expect(form.validate() == false)
        await #expect(updates.next() == .validating)
        await #expect(updates.next() == .invalid)

        // Update the invalid fields with more invalid data
        form.updateField(.invalidField(identifier: "some-id", input: .score(AirshipJSON.number(1.0))))
        #expect(form.status == .invalid)
        form.updateField(.invalidField(identifier: "some-other-id", input: .score(AirshipJSON.number(2.0))))
        #expect(form.status == .invalid)

        // Update the invalid fields with valid and pending fields
        form.updateField(.validField(identifier: "some-id", input: .score(AirshipJSON.number(1.0)), result: .init(value: .score(AirshipJSON.number(1.0)))))
        #expect(form.status == .invalid)

        form.updateField(
            .asyncField(
                identifier: "some-other-id",
                input: .score(AirshipJSON.number(2.0)),
                processDelay: 0.1
            ) {
                .valid(.init(value: .score(AirshipJSON.number(1.0))))
            }
        )
        #expect(form.status == .pendingValidation)
        await #expect(updates.next() == .pendingValidation)
        await #expect(form.validate() == true)


        await #expect(updates.next() == .validating)
        await #expect(updates.next() == .valid)
        #expect(form.status == .valid)
    }

    @Test("Test updating fields in immediate mode starts a validation task")
    func testUpdateFieldsImmediate() async throws {
        let form = ThomasFormState(
            identifier: "some-form-id",
            formType: .form,
            formResponseType: "response type",
            validationMode: .immediate
        )

        var updates = form.statusUpdates.makeAsyncIterator()

        await #expect(updates.next() == .invalid)

        form.updateField(.validField(identifier: "some-valid-id", input: .score(AirshipJSON.number(1.0)), result: .init(value: .score(AirshipJSON.number(1.0)))))
        await #expect(updates.next() == .pendingValidation)
        await #expect(updates.next() == .validating)
        await #expect(updates.next() == .valid)

        form.updateField(.invalidField(identifier: "some-id", input: .score(AirshipJSON.number(1.0))))
        await #expect(updates.next() == .pendingValidation)
        await #expect(updates.next() == .validating)
        await #expect(updates.next() == .invalid)

        form.updateField(.invalidField(identifier: "some-other-id", input: .score(AirshipJSON.number(2.0))))
        await #expect(updates.next() == .pendingValidation)
        await #expect(updates.next() == .validating)
        await #expect(updates.next() == .invalid)

        // Update the invalid fields with more invalid data
        form.updateField(.invalidField(identifier: "some-id", input: .score(AirshipJSON.number(1.0))))
        form.updateField(.invalidField(identifier: "some-other-id", input: .score(AirshipJSON.number(2.0))))

        // Update the invalid fields with valid fields
        form.updateField(.validField(identifier: "some-id", input: .score(AirshipJSON.number(1.0)), result: .init(value: .score(AirshipJSON.number(1.0)))))
        await #expect(updates.next() == .pendingValidation)
        await #expect(updates.next() == .validating)
        await #expect(updates.next() == .invalid)

        form.updateField(.validField(identifier: "some-other-id", input: .score(AirshipJSON.number(1.0)), result: .init(value: .score(AirshipJSON.number(1.0)))))
        await #expect(updates.next() == .pendingValidation)
        await #expect(updates.next() == .validating)
        await #expect(updates.next() == .valid)

        // Update a field with pending
        form.updateField(
            .asyncField(
                identifier: "some-other-id",
                input: .score(AirshipJSON.number(2.0)),
                processDelay: 0.1
            ) {
                .valid(.init(value: .score(AirshipJSON.number(1.0))))
            }
        )
        await #expect(updates.next() == .pendingValidation)
        await #expect(updates.next() == .validating)
        await #expect(updates.next() == .valid)
    }

    @Test("Test enable effects form input enabled")
    func testEnable() async throws {
        let parent = ThomasFormState(
            identifier: "some-form-id",
            formType: .form,
            formResponseType: "response type",
            validationMode: .immediate
        )

        let child = ThomasFormState(
            identifier: "some-form-id",
            formType: .form,
            formResponseType: "response type",
            validationMode: .immediate,
            parentFormState: parent
        )

        #expect(child.isEnabled)
        #expect(child.isFormInputEnabled)
        #expect(parent.isEnabled)
        #expect(parent.isFormInputEnabled)

        parent.isEnabled = false

        #expect(parent.isEnabled == false)
        #expect(parent.isFormInputEnabled  == false)
        #expect(child.isEnabled)
        #expect(child.isFormInputEnabled == false)

        parent.isEnabled = true
        child.isEnabled = false

        #expect(parent.isEnabled)
        #expect(parent.isFormInputEnabled)
        #expect(child.isEnabled == false)
        #expect(child.isFormInputEnabled == false)
    }

    @Test("Test mark child visible.")
    func testMarkChildVisible() async throws {
        let parent = ThomasFormState(
            identifier: "some-form-id",
            formType: .form,
            formResponseType: "response type",
            validationMode: .immediate
        )

        let child = ThomasFormState(
            identifier: "some-form-id",
            formType: .form,
            formResponseType: "response type",
            validationMode: .immediate,
            parentFormState: parent
        )

        #expect(child.isVisible == false)
        #expect(parent.isVisible == false)

        child.markVisible()
        #expect(child.isVisible)
        #expect(parent.isVisible)
    }

    @Test("Test mark parent visible.")
    func testMarkParentVisible() async throws {
        let parent = ThomasFormState(
            identifier: "some-form-id",
            formType: .form,
            formResponseType: "response type",
            validationMode: .immediate
        )

        let child = ThomasFormState(
            identifier: "some-form-id",
            formType: .form,
            formResponseType: "response type",
            validationMode: .immediate,
            parentFormState: parent
        )

        #expect(child.isVisible == false)
        #expect(parent.isVisible == false)

        parent.markVisible()
        #expect(parent.isVisible)
        #expect(child.isVisible == false)

        child.markVisible()
        #expect(child.isVisible)
        #expect(parent.isVisible)
    }
}

extension ThomasFormField {
    var channels: [ThomasFormField.Channel] {
        return if case let .valid(result) = self.status {
            result.channels ?? []
        } else {
            []
        }
    }

    var attributes: [ThomasFormField.Attribute] {
        return if case let .valid(result) = self.status {
            result.attributes ?? []
        } else {
            []
        }
    }
}

extension ThomasFormState {
    // $status.values seems to debounce updates so using a custom updates for
    // testing
    var statusUpdates: AsyncStream<ThomasFormState.Status> {
        return AsyncStream { continuation in
            let sub = self.$status.sink { status in
                continuation.yield(status)
            }

            continuation.onTermination = { _ in
                sub.cancel()
            }
        }
    }
}
