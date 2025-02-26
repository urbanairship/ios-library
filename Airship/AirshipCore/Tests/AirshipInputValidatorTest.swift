/* Copyright Airship and Contributors */

import Testing

@testable import AirshipCore

struct AirshipInputValidatorTest {
    private let validator = AirshipInputValidator { _, _ in true }

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
    func testValidEmail(arg: String) {
        let email = AirshipInputValidator.Email(arg)
        #expect(email.isValidFormat)
        #expect(arg == email.address)
        #expect(validator.validate(email: email))
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
    func testInvalidEmails(arg: String) {
        let email = AirshipInputValidator.Email(arg)
        #expect(!email.isValidFormat)
        #expect(arg.trimmingCharacters(in: .whitespaces) == email.address)
        #expect(!validator.validate(email: email))
    }

    @Test(
        "Test valid email formatting",
        arguments: [
            " user@domain.com",
            "user@domain.com   ",
            "      user@domain.com   "
        ]
    )
    func testEmailFormatting(arg: String) {
        let email = AirshipInputValidator.Email(arg)
        #expect(email.isValidFormat)
        #expect(arg.trimmingCharacters(in: .whitespaces) == email.address)
        #expect(validator.validate(email: email))
    }

    @Test("Test valid phone number with country code")
    func testPhoneNumberWithCountryCode() {
        let phoneNumber = AirshipInputValidator.PhoneNumber("1-555-867-5309", countryCode: "+1")
        #expect(phoneNumber.address == "15558675309")
        #expect(phoneNumber.isValidFormat)
    }

    @Test("Test valid phone number without country code")
    func testPhoneNumberWithoutCountryCode() {
        let phoneNumber = AirshipInputValidator.PhoneNumber("867-5309", countryCode: "+1")
        #expect(phoneNumber.address == "18675309")
        #expect(phoneNumber.isValidFormat)
    }

    @Test(
        "Test valid phone number with different separator characters",
        arguments: [
            "1 555 867 5309",
            "1.555.867.5309",
            "1-555-867-5309",
            "5 5 5 8 6  7 5309",
        ]
    )
    func testPhoneNumberDifferentSeperators(number: String) {
        let phoneNumber = AirshipInputValidator.PhoneNumber(number, countryCode: "+1")
        #expect(phoneNumber.address == "15558675309")
        #expect(phoneNumber.isValidFormat)
    }

    @Test("Test country code when it's already present in the number")
    func testPhoneNumberWithPrefixCheck() {
        var phoneNumber = AirshipInputValidator.PhoneNumber("15558675309", countryCode: "+1")
        #expect(phoneNumber.address == "15558675309")

        phoneNumber = AirshipInputValidator.PhoneNumber("245558675309", countryCode: "+24")
        #expect(phoneNumber.address == "245558675309")

        // Different prefix
        phoneNumber = AirshipInputValidator.PhoneNumber("15558675309", countryCode: "+100")
        #expect(phoneNumber.address == "10015558675309")
    }

    @Test(
        "Test invalid phone numbers",
        arguments: [
            "1-555-867-5309-12345",
            "155586753091234567"
        ]
    )
    func testInvalidPhoneNumberFormats(number: String) {
        let phoneNumber = AirshipInputValidator.PhoneNumber(number, countryCode: "+1")
        #expect(!phoneNumber.isValidFormat)
    }

    @Test("Test validate phone number")
    func testValidatePhoneNumber() async {
        let phoneNumber = AirshipInputValidator.PhoneNumber("15558675309", countryCode: "+1")
        let validation = AirshipInputValidator.PhoneNumberValidation.sender("some sender")

        await confirmation() { confirmation in
            let validator = AirshipInputValidator { incomingNumber, incomingValidation in
                #expect(incomingNumber == phoneNumber)
                #expect(incomingValidation == validation)
                confirmation.confirm()
                return true
            }
            let result = try? await validator.validate(phoneNumber: phoneNumber, validation: validation)
            #expect(result == true)
         }
    }
}
