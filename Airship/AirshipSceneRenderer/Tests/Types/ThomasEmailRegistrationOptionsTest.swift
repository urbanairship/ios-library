/* Copyright Airship and Contributors */

import XCTest

@testable import AirshipCore
@testable @_spi(AirshipInternal) import AirshipSceneRenderer

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

        let options = try JSONDecoder().decode(ThomasEmailRegistrationOption.self, from: json.data(using: .utf8)!)

        let expected: ThomasEmailRegistrationOption = .commercial(
            ThomasEmailRegistrationOption.Commercial(
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

        let options = try JSONDecoder().decode(ThomasEmailRegistrationOption.self, from: json.data(using: .utf8)!)

        let expected: ThomasEmailRegistrationOption = .commercial(
            ThomasEmailRegistrationOption.Commercial(
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

        let options = try JSONDecoder().decode(ThomasEmailRegistrationOption.self, from: json.data(using: .utf8)!)

        let expected: ThomasEmailRegistrationOption = .transactional(
            ThomasEmailRegistrationOption.Transactional(
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

        let options = try JSONDecoder().decode(ThomasEmailRegistrationOption.self, from: json.data(using: .utf8)!)

        let expected: ThomasEmailRegistrationOption = .transactional(
            ThomasEmailRegistrationOption.Transactional(
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

        let options = try JSONDecoder().decode(ThomasEmailRegistrationOption.self, from: json.data(using: .utf8)!)

        let expected: ThomasEmailRegistrationOption = .doubleOptIn(
            ThomasEmailRegistrationOption.DoubleOptIn(
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

        let options = try JSONDecoder().decode(ThomasEmailRegistrationOption.self, from: json.data(using: .utf8)!)

        let expected: ThomasEmailRegistrationOption = .doubleOptIn(
            ThomasEmailRegistrationOption.DoubleOptIn(
                properties: nil
            )
        )
        XCTAssertEqual(expected, options)
    }

}
