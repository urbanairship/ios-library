/* Copyright Airship and Contributors */

import XCTest

@testable import AirshipCore

class ThomasEmailRegistrationOptionsTest: XCTestCase {

    private let date: Date = Date.now

    func testCommercialFromJSON() throws {
        let json = """
        {
           "type": "commercial",
           "commercial_opted_in": true,
           "properties": {
              "cool": "prop"
           }
        }
        """

        let options = try JSONDecoder().decode(ThomasEmailRegistrationOptions.self, from: json.data(using: .utf8)!)

        let expected: ThomasEmailRegistrationOptions = .commercial(
            ThomasEmailRegistrationOptions.Commercial(
                optedIn: true,
                properties: try AirshipJSON.wrap(["cool": "prop"])
            )
        )
        XCTAssertEqual(expected, options)
    }

    func testCommercialNoPropertiesFromJSON() throws {
        let json = """
        {
           "type": "commercial",
           "commercial_opted_in": false
        }
        """

        let options = try JSONDecoder().decode(ThomasEmailRegistrationOptions.self, from: json.data(using: .utf8)!)

        let expected: ThomasEmailRegistrationOptions = .commercial(
            ThomasEmailRegistrationOptions.Commercial(
                optedIn: false,
                properties: nil
            )
        )
        XCTAssertEqual(expected, options)
    }

    func testTransactionalFromJSON() throws {
        let json = """
        {
           "type": "transactional",
           "properties": {
              "cool": "prop"
           }
        }
        """

        let options = try JSONDecoder().decode(ThomasEmailRegistrationOptions.self, from: json.data(using: .utf8)!)

        let expected: ThomasEmailRegistrationOptions = .transactional(
            ThomasEmailRegistrationOptions.Transactional(
                properties: try AirshipJSON.wrap(["cool": "prop"])
            )
        )
        XCTAssertEqual(expected, options)
    }

    func testTransactionalNoPropertiesFromJSON() throws {
        let json = """
        {
           "type": "transactional"
        }
        """

        let options = try JSONDecoder().decode(ThomasEmailRegistrationOptions.self, from: json.data(using: .utf8)!)

        let expected: ThomasEmailRegistrationOptions = .transactional(
            ThomasEmailRegistrationOptions.Transactional(
                properties: nil
            )
        )
        XCTAssertEqual(expected, options)
    }

    func testDoubleOptInFromJSON() throws {
        let json = """
        {
           "type": "double_opt_in",
           "properties": {
              "cool": "prop"
           }
        }
        """

        let options = try JSONDecoder().decode(ThomasEmailRegistrationOptions.self, from: json.data(using: .utf8)!)

        let expected: ThomasEmailRegistrationOptions = .doubleOptIn(
            ThomasEmailRegistrationOptions.DoubleOptIn(
                properties: try AirshipJSON.wrap(["cool": "prop"])
            )
        )
        XCTAssertEqual(expected, options)
    }

    func testDoubleOptInNoPropertiesFromJSON() throws {
        let json = """
        {
           "type": "double_opt_in"
        }
        """

        let options = try JSONDecoder().decode(ThomasEmailRegistrationOptions.self, from: json.data(using: .utf8)!)

        let expected: ThomasEmailRegistrationOptions = .doubleOptIn(
            ThomasEmailRegistrationOptions.DoubleOptIn(
                properties: nil
            )
        )
        XCTAssertEqual(expected, options)
    }

    func testCommercialToContactOptions() throws {
        let options: ThomasEmailRegistrationOptions = .commercial(
            ThomasEmailRegistrationOptions.Commercial(
                optedIn: true,
                properties: try AirshipJSON.wrap(["cool": "prop"])
            )
        )

        let expected = EmailRegistrationOptions.commercialOptions(
            transactionalOptedIn: nil,
            commercialOptedIn: date,
            properties: ["cool": "prop"]
        )
        XCTAssertEqual(options.makeContactOptions(date: date), expected)
    }

    func testCommercialNoPropertiesToContactOptions() {
        let options: ThomasEmailRegistrationOptions = .commercial(
            ThomasEmailRegistrationOptions.Commercial(
                optedIn: false,
                properties: nil
            )
        )

        let expected = EmailRegistrationOptions.commercialOptions(
            transactionalOptedIn: nil,
            commercialOptedIn: nil,
            properties: nil
        )
        XCTAssertEqual(options.makeContactOptions(date: date), expected)
    }

    func testTransactionalToContactOptions() throws {
        let options: ThomasEmailRegistrationOptions = .transactional(
            ThomasEmailRegistrationOptions.Transactional(
                properties: try AirshipJSON.wrap(["cool": "prop"])
            )
        )

        let expected = EmailRegistrationOptions.options(
            transactionalOptedIn: nil,
            properties: ["cool": "prop"],
            doubleOptIn: false
        )
        XCTAssertEqual(options.makeContactOptions(date: date), expected)
    }

    func testTransactionalNoPropertiesToContactOptions() {
        let options: ThomasEmailRegistrationOptions = .transactional(
            ThomasEmailRegistrationOptions.Transactional(
                properties: nil
            )
        )

        let expected = EmailRegistrationOptions.options(
            transactionalOptedIn: nil,
            properties: nil,
            doubleOptIn: false
        )
        XCTAssertEqual(options.makeContactOptions(date: date), expected)
    }

    func testDoubleOptInToContactOptions() throws {
        let options: ThomasEmailRegistrationOptions = .doubleOptIn(
            ThomasEmailRegistrationOptions.DoubleOptIn(
                properties: try AirshipJSON.wrap(["cool": "prop"])
            )
        )

        let expected = EmailRegistrationOptions.options(properties: ["cool": "prop"], doubleOptIn: true)
        XCTAssertEqual(options.makeContactOptions(date: date), expected)
    }

    func testDoubleOptInNoPropertiesToContactOptions() {
        let options: ThomasEmailRegistrationOptions = .doubleOptIn(
            ThomasEmailRegistrationOptions.DoubleOptIn(
                properties: nil
            )
        )

        let expected = EmailRegistrationOptions.options(properties: nil, doubleOptIn: true)
        XCTAssertEqual(options.makeContactOptions(date: date), expected)
    }


}
