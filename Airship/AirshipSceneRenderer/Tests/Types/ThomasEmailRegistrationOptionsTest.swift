/* Copyright Airship and Contributors */

import Foundation
import Testing

@testable import AirshipBasement
@testable @_spi(AirshipInternal) import AirshipSceneRenderer

@Suite(.timeLimit(.minutes(1)))
struct ThomasEmailRegistrationOptionsTest {

    @Test
    func commercialFromJSON() throws {
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
        #expect(expected == options)
    }

    @Test
    func commercialNoPropertiesFromJSON() throws {
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
        #expect(expected == options)
    }

    @Test
    func transactionalFromJSON() throws {
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
        #expect(expected == options)
    }

    @Test
    func transactionalNoPropertiesFromJSON() throws {
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
        #expect(expected == options)
    }

    @Test
    func doubleOptInFromJSON() throws {
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
        #expect(expected == options)
    }

    @Test
    func doubleOptInNoPropertiesFromJSON() throws {
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
        #expect(expected == options)
    }
}
