/* Copyright Airship and Contributors */

import Testing


@testable import AirshipCore

struct AirshipInputValidationTest {
    private let smsValidatorAPIClient = TestSMSValidatorAPIClient()

    @Test(
        "Test valid email addresses",
        arguments: [
            "simple@example.com",
            "very.common@example.com",
            "disposable.style.email.with+symbol@example.com",
            "other.email-with-hyphen@example.com",
            "fully-qualified-domain@example.com",
            "user.name+tag+sorting@example.com",
            "x@y.z",
            "user123@domain.com",
            "user.name@domain.com",
            "a@domain.com",
            "user@sub.domain.com",
            "user-name@domain.com",
            "user.@domain.com",
            ".user@domain.com",
            "user@.domain.com",
            "user@domain..com",
            "user..name@domain.com",
            "user+name@domain.com",
            "user!#$%&'*+-/=?^_`{|}~@domain.com"
        ]
    )
    func testValidEmail(arg: String) async throws {
        let validator = AirshipInputValidation.DefaultValidator(
            smsValidatorAPIClient: smsValidatorAPIClient
        )

        let request = AirshipInputValidation.Request.email(
            .init(rawInput: arg)
        )

        let result = try await validator.validateRequest(request)

        #expect(result == .valid(address: arg))
    }


    @Test(
        "Test invalid emails",
        arguments: [
            "user",
            "user ",
            "",
            "user@",
            "user@domain",
            "user @domain.com",
            "user@ domain.com",
            "us er@domain.com",
            "user@do main.com",
            "user@domain.com.",
            "user@domain@example.com"
        ]
    )
    func testInvalidEmails(arg: String) async throws {
        let validator = AirshipInputValidation.DefaultValidator(
            smsValidatorAPIClient: smsValidatorAPIClient
        )

        let request = AirshipInputValidation.Request.email(
            .init(rawInput: arg)
        )

        let result = try await validator.validateRequest(request)

        #expect(result == .invalid)
    }

    @Test(
        "Test valid email formatting",
        arguments: [
            " user@domain.com",
            "user@domain.com   ",
            "      user@domain.com   "
        ]
    )
    func testEmailFormatting(arg: String) async throws {
        let validator = AirshipInputValidation.DefaultValidator(
            smsValidatorAPIClient: smsValidatorAPIClient
        )

        let request = AirshipInputValidation.Request.email(
            .init(rawInput: arg)
        )

        let result = try await validator.validateRequest(request)

        let trimmed = arg.trimmingCharacters(in: .whitespacesAndNewlines)
        #expect(result == .valid(address: trimmed))
    }

    @Test("Test email override.")
    func testEmailOverride() async throws {
        let request = AirshipInputValidation.Request.email(
            .init(rawInput: "some-valid@email.com")
        )

        try await confirmation { confirmation in
            let validator = AirshipInputValidation.DefaultValidator(
                smsValidatorAPIClient: smsValidatorAPIClient
            ) { arg in
                #expect(arg == request)
                confirmation.confirm()
                return .override(.valid(address: "some other result"))
            }

            let result = try await validator.validateRequest(request)
            #expect(result == .valid(address: "some other result"))
        }
    }

    @Test("Test email override default fallback.")
    func testEmailOverrideFallback() async throws {
        let request = AirshipInputValidation.Request.email(
            .init(rawInput: " some-valid@email.com ")
        )

        try await confirmation { confirmation in
            let validator = AirshipInputValidation.DefaultValidator(
                smsValidatorAPIClient: smsValidatorAPIClient
            ) { arg in
                #expect(arg == request)
                confirmation.confirm()
                return .useDefault
            }

            let result = try await validator.validateRequest(request)
            #expect(result == .valid(address: "some-valid@email.com"))
        }
    }

    @Test("Test sms validation with sender ID")
    func testSMSValidationWithSenderID() async throws {
        let request = AirshipInputValidation.Request.sms(
            .init(
                rawInput: "555555555",
                validationOptions: .sender(senderID: "some sender", prefix: nil)
            )
        )

        let validator = AirshipInputValidation.DefaultValidator(
            smsValidatorAPIClient: smsValidatorAPIClient
        )

        try await confirmation { confirmation in
            await smsValidatorAPIClient.setOnValidate { apiRequest in
                #expect(apiRequest.msisdn == "555555555")
                #expect(apiRequest.sender == "some sender")
                confirmation.confirm()
                return AirshipHTTPResponse(
                    result: .valid("+1555555555"),
                    statusCode: 200,
                    headers: [:]
                )
            }

            let result = try await validator.validateRequest(request)
            #expect(result == .valid(address: "+1555555555"))
        }
    }

    @Test("Test sms validation with prefix")
    func testSMSValidationWithPrefix() async throws {
        let request = AirshipInputValidation.Request.sms(
            .init(
                rawInput: "555555555",
                validationOptions: .prefix(prefix: "+1")
            )
        )

        let validator = AirshipInputValidation.DefaultValidator(
            smsValidatorAPIClient: smsValidatorAPIClient
        )

        try await confirmation { confirmation in
            await smsValidatorAPIClient.setOnValidate { apiRequest in
                #expect(apiRequest.msisdn == "555555555")
                #expect(apiRequest.prefix == "+1")
                confirmation.confirm()
                return AirshipHTTPResponse(
                    result: .valid("+1555555555"),
                    statusCode: 200,
                    headers: [:]
                )
            }

            let result = try await validator.validateRequest(request)
            #expect(result == .valid(address: "+1555555555"))
        }
    }

    @Test("Test sms validation 4xx response should return invalid")
    func testSMSValidationWith400Response() async throws {
        let request = AirshipInputValidation.Request.sms(
            .init(
                rawInput: "555555555",
                validationOptions: .sender(senderID: "some sender", prefix: nil)
            )
        )

        let validator = AirshipInputValidation.DefaultValidator(
            smsValidatorAPIClient: smsValidatorAPIClient
        )

        try await confirmation { confirmation in
            await smsValidatorAPIClient.setOnValidate { apiRequest in
                #expect(apiRequest.msisdn == "555555555")
                #expect(apiRequest.sender == "some sender")
                confirmation.confirm()
                return AirshipHTTPResponse(
                    result: nil,
                    statusCode: Int.random(in: 400...499),
                    headers: [:]
                )
            }

            let result = try await validator.validateRequest(request)
            #expect(result == .invalid)
        }
    }

    @Test("Test sms validation 5xx should throw")
    func testSMSValidationWith500Response() async throws {
        let request = AirshipInputValidation.Request.sms(
            .init(
                rawInput: "555555555",
                validationOptions: .sender(senderID: "some sender", prefix: nil)
            )
        )

        let validator = AirshipInputValidation.DefaultValidator(
            smsValidatorAPIClient: smsValidatorAPIClient
        )

        await confirmation { confirmation in
            await smsValidatorAPIClient.setOnValidate { apiRequest in
                #expect(apiRequest.msisdn == "555555555")
                #expect(apiRequest.sender == "some sender")
                confirmation.confirm()
                return AirshipHTTPResponse(
                    result: nil,
                    statusCode: Int.random(in: 500...599),
                    headers: [:]
                )
            }

            await #expect(throws: NSError.self) {
                _ = try await validator.validateRequest(request)
            }
        }
    }

    @Test("Test sms validation 2xx without a result should throw")
    func testSMSValidationWith200ResponseNoResult() async throws {
        let request = AirshipInputValidation.Request.sms(
            .init(
                rawInput: "555555555",
                validationOptions: .sender(senderID: "some sender", prefix: nil)
            )
        )

        let validator = AirshipInputValidation.DefaultValidator(
            smsValidatorAPIClient: smsValidatorAPIClient
        )

        await confirmation { confirmation in
            await smsValidatorAPIClient.setOnValidate { apiRequest in
                #expect(apiRequest.msisdn == "555555555")
                #expect(apiRequest.sender == "some sender")
                confirmation.confirm()
                return AirshipHTTPResponse(
                    result: nil,
                    statusCode: Int.random(in: 200...299),
                    headers: [:]
                )
            }

            await #expect(throws: NSError.self) {
                _ = try await validator.validateRequest(request)
            }
        }
    }

    @Test("Test validation hints are checked before API client")
    func testValidationHints() async throws {
        // Setup a valid response
        await smsValidatorAPIClient.setOnValidate { apiRequest in
            return AirshipHTTPResponse(
                result: .valid("+1555555555"),
                statusCode: 200,
                headers: [:]
            )
        }

        let validator = AirshipInputValidation.DefaultValidator(
            smsValidatorAPIClient: smsValidatorAPIClient
        )

        // Test 0-3 digits
        for i in 0...3 {
            let request = AirshipInputValidation.Request.sms(
                .init(
                    rawInput: generateRandomNumberString(length: i),
                    validationOptions: .sender(senderID: "some sender", prefix: nil),
                    validationHints: .init(minDigits: 4, maxDigits: 6)
                )
            )
            try await #expect(validator.validateRequest(request) == .invalid)
        }

        // Test 4-6 digits
        for i in 4...6 {
            let request = AirshipInputValidation.Request.sms(
                .init(
                    rawInput: generateRandomNumberString(length: i),
                    validationOptions: .sender(senderID: "some sender", prefix: nil),
                    validationHints: .init(minDigits: 4, maxDigits: 6)
                )
            )
            try await #expect(validator.validateRequest(request) == .valid(address: "+1555555555"))
        }

        // Test over 6 digits
        for i in 7...10 {
            let request = AirshipInputValidation.Request.sms(
                .init(
                    rawInput: generateRandomNumberString(length: i),
                    validationOptions: .sender(senderID: "some sender", prefix: nil),
                    validationHints: .init(minDigits: 4, maxDigits: 6)
                )
            )
            try await #expect(validator.validateRequest(request) == .invalid)
        }

        // Test digits with other characters
        let request = AirshipInputValidation.Request.sms(
            .init(
                rawInput: "a1b2c3d4b5e6",
                validationOptions: .sender(senderID: "some sender", prefix: nil),
                validationHints: .init(minDigits: 4, maxDigits: 6)
            )
        )
        try await #expect(validator.validateRequest(request) == .valid(address: "+1555555555"))
    }

    @Test("Test SMS override.")
    func testSMSOverride() async throws {
        let request = AirshipInputValidation.Request.sms(
            .init(
                rawInput: "555555555",
                validationOptions: .sender(senderID: "some sender", prefix: nil)
            )
        )

        try await confirmation { confirmation in
            let validator = AirshipInputValidation.DefaultValidator(
                smsValidatorAPIClient: smsValidatorAPIClient
            ) { arg in
                #expect(arg == request)
                confirmation.confirm()
                return .override(.valid(address: "some other result"))
            }

            let result = try await validator.validateRequest(request)
            #expect(result == .valid(address: "some other result"))
        }
    }

    @Test("Test SMS override default fallback.")
    func testSMSOverrideFallback() async throws {
        let request = AirshipInputValidation.Request.sms(
            .init(
                rawInput: "555555555",
                validationOptions: .sender(senderID: "some sender", prefix: nil)
            )
        )

        try await confirmation(expectedCount: 2) { confirmation in
            await smsValidatorAPIClient.setOnValidate { apiRequest in
                #expect(apiRequest.msisdn == "555555555")
                #expect(apiRequest.sender == "some sender")
                confirmation.confirm()
                return AirshipHTTPResponse(
                    result: .valid("API result"),
                    statusCode: Int.random(in: 200...299),
                    headers: [:]
                )
            }

            let validator = AirshipInputValidation.DefaultValidator(
                smsValidatorAPIClient: smsValidatorAPIClient
            ) { arg in
                #expect(arg == request)
                confirmation.confirm()
                return .useDefault
            }

            let result = try await validator.validateRequest(request)
            #expect(result == .valid(address: "API result"))
        }
    }

    @Test(
        "Test SMS legacy delegate receives formatted input",
        arguments: [
            "1 555 867 5309",
            "1.555.867.5309",
            "1-555-867-5309",
            "5 5 5 8 6  7 5309",
        ]
    )
    func testSMSLegacyDelegate(arg: String) async throws {
        let request = AirshipInputValidation.Request.sms(
            .init(
                rawInput: arg,
                validationOptions: .sender(senderID: "some sender", prefix: "+1")
            )
        )

        let validator = AirshipInputValidation.DefaultValidator(
            smsValidatorAPIClient: smsValidatorAPIClient
        )

        try await confirmation { confirmation in
            let delegate = TestLegacySMSDelegate { msisdn, sender in
                #expect(msisdn == "15558675309")
                #expect(sender == "some sender")
                confirmation.confirm()
                return true
            }

            await Task { @MainActor in
                validator.legacySMSDelegate = delegate
            }.value

            let result = try await validator.validateRequest(request)
            #expect(result == .valid(address: "15558675309"))
        }
    }

    @Test("Test SMS legacy delegate invalid")
    func testLegacySMSDelegateInvalidates() async throws {
        let request = AirshipInputValidation.Request.sms(
            .init(
                rawInput: "123456",
                validationOptions: .sender(senderID: "some sender", prefix: "+1")
            )
        )

        let validator = AirshipInputValidation.DefaultValidator(
            smsValidatorAPIClient: smsValidatorAPIClient
        )

        try await confirmation { confirmation in
            let delegate = TestLegacySMSDelegate { msisdn, sender in
                #expect(msisdn == "123456")
                #expect(sender == "some sender")
                confirmation.confirm()
                return false
            }

            await Task { @MainActor in
                validator.legacySMSDelegate = delegate
            }.value

            let result = try await validator.validateRequest(request)
            #expect(result == .invalid)
        }
    }

    @Test("Test SMS legacy delegate invalid")
    func testLegacySMSDelegateNoPrefix() async throws {
        let request = AirshipInputValidation.Request.sms(
            .init(
                rawInput: "123456",
                validationOptions: .sender(senderID: "some sender", prefix: nil)
            )
        )

        let validator = AirshipInputValidation.DefaultValidator(
            smsValidatorAPIClient: smsValidatorAPIClient
        )

        try await confirmation { confirmation in
            let delegate = TestLegacySMSDelegate { msisdn, sender in
                #expect(msisdn == "123456")
                #expect(sender == "some sender")
                confirmation.confirm()
                return false
            }

            await Task { @MainActor in
                validator.legacySMSDelegate = delegate
            }.value

            let result = try await validator.validateRequest(request)
            #expect(result == .invalid)
        }
    }

    @Test("Test SMS legacy delegate ignored when only prefix")
    func testLegacySMSDelegatePrefix() async throws {
        let request = AirshipInputValidation.Request.sms(
            .init(
                rawInput: "123456",
                validationOptions: .prefix(prefix: "+1")
            )
        )

        let validator = AirshipInputValidation.DefaultValidator(
            smsValidatorAPIClient: smsValidatorAPIClient
        )

        try await confirmation { confirmation in
            let delegate = TestLegacySMSDelegate { msisdn, sender in
                return false
            }

            await smsValidatorAPIClient.setOnValidate { apiRequest in
                #expect(apiRequest.msisdn == "123456")
                #expect(apiRequest.prefix == "+1")
                confirmation.confirm()
                return AirshipHTTPResponse(
                    result: .valid("API result"),
                    statusCode: Int.random(in: 200...299),
                    headers: [:]
                )
            }

            await Task { @MainActor in
                validator.legacySMSDelegate = delegate
            }.value

            let result = try await validator.validateRequest(request)
            #expect(result == .valid(address: "API result"))
        }
    }
}

fileprivate actor TestLegacySMSDelegate: SMSValidatorDelegate {

    var onValidate: (@Sendable (String, String) async throws -> Bool)

    init(onValidate: @Sendable @escaping (String, String) -> Bool) {
        self.onValidate = onValidate
    }

    func validateSMS(msisdn: String, sender: String) async throws -> Bool {
        return try await onValidate(msisdn, sender)
    }
}

// Helpers
fileprivate extension AirshipInputValidationTest {
    func generateRandomNumberString(length: Int) -> String {
        let digits = "0123456789"
        var result = ""

        for _ in 0..<length {
            if let randomCharacter = digits.randomElement() {
                result.append(randomCharacter)
            }
        }

        return result
    }
}
