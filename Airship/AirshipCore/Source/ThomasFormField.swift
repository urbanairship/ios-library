/* Copyright Airship and Contributors */

import Foundation

@MainActor
final class ThomasFormField: Sendable {

    struct Result: Equatable, Sendable {
        var value: Value
        var channels: [Channel]? = nil
        var attributes: [Attribute]? = nil
    }
    
    enum Status: Equatable, Sendable {

        /// The field is valid and passes all validation checks.
        case valid(Result)

        /// The field is invalid due to errors or missing information.
        case invalid

        /// The field is awaiting validation, meaning it's in a pending state.
        case pending

        /// An error occurred while validating the field.
        case error

        var isValid: Bool {
            if case .valid(_) = self {
                return true
            }
            return false
        }
    }

    enum Channel: Sendable, Equatable, Hashable {
        case email(String, ThomasEmailRegistrationOption)
        case sms(String, ThomasSMSRegistrationOption)
    }

    struct Attribute: Sendable, Equatable, Hashable {
        let attributeName: ThomasAttributeName
        let attributeValue: ThomasAttributeValue
    }

    enum Value: Sendable, Equatable {
        case toggle(Bool)
        case radio(String?)
        case multipleCheckbox(Set<String>)
        case form(responseType: String?, children: [String: Value])
        case npsForm(responseType: String?, scoreID: String, children: [String: Value])
        case text(String?)
        case email(String?)
        case sms(String?)
        case score(Int?)
    }

    private enum FieldType: Sendable {
        // Immediate result. If nil, its invalid.
        case just(Result?)

        // Async result
        case async(any ThomasFormFieldPendingRequest)
    }

    var status: Status {
        switch(self.fieldType) {
        case .just(let result):
            if let result {
                .valid(result)
            } else {
                .invalid
            }
        case .async(let pending):
            pending.result?.status ?? .pending
        }
    }

    func cancel() {
        switch(self.fieldType) {
        case .just:
            break
        case .async(let operation):
            operation.cancel()
        }
    }


    private let fieldType: FieldType

    let identifier: String
    let input: Value

    /// Initializes a validator instance.
    /// - Parameter method: The method used to perform the validation.
    private init(
        identifier: String,
        input: Value,
        fieldType: FieldType
    ) {
        self.identifier = identifier
        self.input = input
        self.fieldType = fieldType
    }

    static func asyncField(
        identifier: String,
        input: Value,
        processDelay: TimeInterval = 1.0,
        processor: any ThomasFormFieldProcessor = DefaultThomasFormFieldProcessor(),
        resultBlock: @escaping @MainActor @Sendable () async throws -> ThomasFormFieldPendingResult
    ) -> Self {
        .init(
            identifier: identifier,
            input: input,
            fieldType: .async(
                processor.submit(
                    processDelay: processDelay,
                    resultBlock: resultBlock
                )
            )
        )
    }

    static func invalidField(
        identifier: String,
        input: Value
    ) -> Self {
        return .init(
            identifier: identifier,
            input: input,
            fieldType: .just(nil)
        )
    }

    static func validField(
        identifier: String,
        input: Value,
        result: Result
    ) -> Self {
        return .init(
            identifier: identifier,
            input: input,
            fieldType: .just(result)
        )
    }

    var statusUpdates: AsyncStream<Status> {
        switch(self.fieldType) {
        case .async(let pending):
            return pending.resultUpdates {
                $0?.status ?? .pending
            }
        case .just:
            return AsyncStream { continuation in
                continuation.yield(status)
                continuation.finish()
            }
        }
    }

    func process(retryErrors: Bool = true) async {
        switch(self.fieldType) {
        case .async(let pending):
            await pending.process(retryErrors: retryErrors)
        case .just:
            break
        }
    }
}

fileprivate extension ThomasFormFieldPendingResult {
    var status: ThomasFormField.Status {
        switch (self) {
        case .valid(let result): .valid(result)
        case .invalid: .invalid
        case .error: .error
        }
    }
}
