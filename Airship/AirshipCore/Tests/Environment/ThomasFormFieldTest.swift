/* Copyright Airship and Contributors */

import Testing
import Foundation

@testable import AirshipCore

@MainActor
struct ThomasFormFieldTest {

    @Test("Test invalid field.")
    func testInvalidField() async throws {
        let field = ThomasFormField.invalidField(
            identifier: "some-ID",
            input: .text("some-text")
        )

        #expect(field.status == .invalid)

        // Process does nothing
        await field.process(retryErrors: true)
        await field.process(retryErrors: false)

        #expect(field.status == .invalid)

        var statusUpdates = field.statusUpdates.makeAsyncIterator()
        #expect(await statusUpdates.next() == .invalid)
    }

    @Test("Test valid field.")
    func testValidFieldStatus() async throws {
        let field = ThomasFormField.validField(
            identifier: "some-ID",
            input: .text("some-text"),
            result: .init(value: .text("some-other-text"))
        )

        #expect(field.status == .valid(.init(value: .text("some-other-text"))))

        // Process does nothing
        await field.process(retryErrors: true)
        await field.process(retryErrors: false)

        #expect(field.status == .valid(.init(value: .text("some-other-text"))))

        var statusUpdates = field.statusUpdates.makeAsyncIterator()
        #expect(await statusUpdates.next() == .valid(.init(value: .text("some-other-text"))))
    }

    @Test("Test async field.")
    func testAsyncField() async throws {
        let pendingRequest = TestPendinRequest()
        let processor = TestProcesssor()
        processor.onSubmit = { interval, resultBlock in
            #expect(interval == 3.0)
            pendingRequest.resultBlock = resultBlock
            return pendingRequest
        }

        let field = ThomasFormField.asyncField(
            identifier: "some-ID",
            input: .text("some-text"),
            processDelay: 3.0,
            processor: processor
        ) {
            .valid(.init(value: .text("some valid text")))
        }

        #expect(field.status == .pending)
        #expect(pendingRequest.didProcess == false)
        #expect(pendingRequest.didRetry == false)

        await field.process(retryErrors: false)
        #expect(pendingRequest.didProcess == true)
        #expect(pendingRequest.didRetry == false)

        pendingRequest.didProcess = false
        await field.process(retryErrors: true)
        #expect(pendingRequest.didProcess == true)
        #expect(pendingRequest.didRetry == true)

        var statusUpdates = field.statusUpdates.makeAsyncIterator()
        #expect(await statusUpdates.next() == .pending)

        // Update the result
        pendingRequest.result = try await pendingRequest.resultBlock?()
        #expect(await statusUpdates.next() == .valid(.init(value: .text("some valid text"))))

        // Update the result to the error
        pendingRequest.result = .error
        #expect(await statusUpdates.next() == .error)
        #expect(field.status == .error)

        // Update the result to the error
        pendingRequest.result = .invalid
        #expect(await statusUpdates.next() == .invalid)
        #expect(field.status == .invalid)
    }

    @MainActor
    fileprivate class TestPendinRequest: ThomasFormFieldPendingRequest {
        func cancel() {

        }
        
        var result: ThomasFormFieldPendingResult? {
            didSet {
                onResult.values.forEach { $0(result) }
            }
        }

        var onResult: [String: (ThomasFormFieldPendingResult?) -> Void] = [:]
        var resultBlock: (@MainActor @Sendable () async throws -> ThomasFormFieldPendingResult)?

        func resultUpdates<T>(
            mapper: @escaping @Sendable (ThomasFormFieldPendingResult?) -> T
        ) -> AsyncStream<T> where T : Sendable {
            return AsyncStream { continuation in
                continuation.yield(mapper(result))

                let id = UUID().uuidString

                onResult[id] = { result in
                    continuation.yield(mapper(result))
                }

                continuation.onTermination = { _ in
                    Task { @MainActor in
                        self.onResult[id] = nil
                    }
                }
            }
        }

        var didProcess: Bool = false
        var didRetry: Bool = false

        func process(retryErrors: Bool) async {
            didProcess = true
            didRetry = retryErrors
        }
    }

    @MainActor
    fileprivate class TestProcesssor: ThomasFormFieldProcessor {

        var onSubmit: ((TimeInterval, @escaping @MainActor @Sendable () async throws -> ThomasFormFieldPendingResult) -> TestPendinRequest)?

        func submit(
            processDelay: TimeInterval,
            resultBlock: @escaping @MainActor @Sendable () async throws -> ThomasFormFieldPendingResult
        ) -> any ThomasFormFieldPendingRequest {
            return onSubmit!(processDelay, resultBlock)
        }
    }
}

