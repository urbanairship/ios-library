import XCTest
@testable import AirshipCore

class SMSValidatorTests: XCTestCase {
    var smsValidator: SMSValidator!
    var testAPIClient: TestSMSValidatorAPIClient!

    override func setUp() {
        super.setUp()
        testAPIClient = TestSMSValidatorAPIClient()
        smsValidator = SMSValidator(apiClient: testAPIClient)
    }

    override func tearDown() {
        smsValidator = nil
        testAPIClient = nil
        super.tearDown()
    }

    /// Test when API returns true validator does also
    func testValidMSISDNReturnsTrue() async throws {
        let msisdn = "1234567890"
        let sender = "TestSender"
        testAPIClient.validationResult = true

        let result = try await smsValidator.validateSMS(msisdn: msisdn, sender: sender)

        XCTAssertTrue(result)
    }

    /// Test when API returns false validator does also
    func testInvalidMSISDNReturnsFalse() async throws {
        let msisdn = "1234567890"
        let sender = "TestSender"
        testAPIClient.validationResult = false

        let result = try await smsValidator.validateSMS(msisdn: msisdn, sender: sender)

        XCTAssertFalse(result)
    }

    /// Test when first API result is invalid no subsequent calls to API are made and validator returns false for each
    func testPreviouslyFailedValidationReturnsFalse() async throws {
        let msisdn = "1234567890"
        let sender = "TestSender"
        testAPIClient.validationResult = false

        let result1 = try await smsValidator.validateSMS(msisdn: msisdn, sender: sender)
        let result2 = try await smsValidator.validateSMS(msisdn: msisdn, sender: sender)

        XCTAssertFalse(result1)
        XCTAssertFalse(result2)
        XCTAssertEqual(testAPIClient.validationCallCount, 1)
    }
}

class TestSMSValidatorAPIClient: SMSValidatorAPIClientProtocol, @unchecked Sendable {
    var validationResult: Bool = true
    var lastMSISDN: String?
    var lastSender: String?
    var validationCallCount = 0

    func validateSMS(msisdn: String, sender: String) async throws -> AirshipHTTPResponse<Bool> {
        validationCallCount += 1
        lastMSISDN = msisdn
        lastSender = sender
        return AirshipHTTPResponse(result: validationResult, statusCode: 200, headers: ["cool" : "headers"])
    }
}
