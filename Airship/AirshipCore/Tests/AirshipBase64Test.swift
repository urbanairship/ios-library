/* Copyright Airship and Contributors */

import XCTest
@testable import AirshipCore

class AirshipBase64Test: XCTestCase {

    // Examples from Wikipedia page on base64 encoding
    // http://en.wikipedia.org/wiki/Base64
    // These test strings were encoded/decoded with Python 2.7.2 base64 lib to check for errors
    // Note the period (.), it is part of the encoding, as well as the '=' sign, it is used
    // for padding.

    //>>> one = base64.b64encode('pleasure.')
    //>>> print(one)
    //cGxlYXN1cmUu
    //>>> one == 'cGxlYXN1cmUu'
    //True
    //>>> one = base64.b64encode('leasure.')
    //>>> one == 'bGVhc3VyZS4='
    //True
    //>>> one = base64.b64encode('easure.')
    //>>> one == 'ZWFzdXJlLg=='
    //True
    //>>>

    let pleasure = "pleasure."
    let pleasure64 = "cGxlYXN1cmUu"

    let leasure = "leasure."
    let leasure64 = "bGVhc3VyZS4="

    let easure = "easure."
    let easure64 = "ZWFzdXJlLg=="
    let easure64PartiallyPadded = "ZWFzdXJlLg="
    let easure64Unpadded = "ZWFzdXJlLg"
    let easure64Newline = "ZWFzdXJlLg\n"
    let easure64InterstitialNewline = "ZWFzdXJlLg=\n="

    func testBase64Encode() {
        let dataToEncode = pleasure.data(using: .ascii)!
        let encoded = AirshipBase64.string(from: dataToEncode)
        XCTAssertTrue(encoded == pleasure64)

        let dataToEncode2 = leasure.data(using: .ascii)!
        let encoded2 = AirshipBase64.string(from: dataToEncode2)
        XCTAssertTrue(encoded2 == leasure64)

        let dataToEncode3 = easure.data(using: .ascii)!
        let encoded3 = AirshipBase64.string(from: dataToEncode3)
        XCTAssertTrue(encoded3 == easure64)
    }

    func testBase64Decode() {
        var decodedData = AirshipBase64.data(from: pleasure64)!
        var decodedString = String(data: decodedData, encoding: .ascii)!
        XCTAssertTrue(decodedString == pleasure)

        decodedData = AirshipBase64.data(from: leasure64)!
        decodedString = String(data: decodedData, encoding: .ascii)!
        XCTAssertTrue(decodedString == leasure)

        decodedData = AirshipBase64.data(from: easure64)!
        decodedString = String(data: decodedData, encoding: .ascii)!
        XCTAssertTrue(decodedString == easure)

        decodedData = AirshipBase64.data(from: easure64PartiallyPadded)!
        decodedString = String(data: decodedData, encoding: .ascii)!
        XCTAssertTrue(decodedString == easure)

        decodedData = AirshipBase64.data(from: easure64Unpadded)!
        decodedString = String(data: decodedData, encoding: .ascii)!
        XCTAssertTrue(decodedString == easure)

        decodedData = AirshipBase64.data(from: easure64Newline)!
        decodedString = String(data: decodedData, encoding: .ascii)!
        XCTAssertTrue(decodedString == easure)

        decodedData = AirshipBase64.data(from: easure64InterstitialNewline)!
        decodedString = String(data: decodedData, encoding: .ascii)!
        XCTAssertTrue(decodedString == easure)
    }

    func testBase64DecodeInvalidString() {
        XCTAssertNoThrow(AirshipBase64.data(from: "."))
        XCTAssertNoThrow(AirshipBase64.data(from: " "))
    }
}
