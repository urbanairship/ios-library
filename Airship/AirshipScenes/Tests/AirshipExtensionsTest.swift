/* Copyright Airship and Contributors */

import Testing
import Foundation

@testable @_spi(AirshipInternal) import AirshipCore
@testable @_spi(AirshipInternal) import AirshipSceneRenderer
@testable @_spi(AirshipInternal) import AirshipScenes

struct AirshipExtensionsTest {

    private let date: Date = Date.now

    @Test
    func commercialToContactOptions() throws {
        let options: ThomasEmailRegistrationOption = .commercial(
            ThomasEmailRegistrationOption.Commercial(
                optedIn: true,
                properties: try AirshipJSON.wrap(["cool": "prop"])
            )
        )

        let expected = EmailRegistrationOptions.commercialOptions(
            transactionalOptedIn: nil,
            commercialOptedIn: date,
            properties: ["cool": "prop"]
        )
        #expect(options.makeContactOptions(date: date) == expected)
    }

    @Test
    func commercialNoPropertiesToContactOptions() {
        let options: ThomasEmailRegistrationOption = .commercial(
            ThomasEmailRegistrationOption.Commercial(
                optedIn: false,
                properties: nil
            )
        )

        let expected = EmailRegistrationOptions.commercialOptions(
            transactionalOptedIn: nil,
            commercialOptedIn: nil,
            properties: nil
        )
        #expect(options.makeContactOptions(date: date) == expected)
    }

    @Test
    func transactionalToContactOptions() throws {
        let options: ThomasEmailRegistrationOption = .transactional(
            ThomasEmailRegistrationOption.Transactional(
                properties: try AirshipJSON.wrap(["cool": "prop"])
            )
        )

        let expected = EmailRegistrationOptions.options(
            transactionalOptedIn: nil,
            properties: ["cool": "prop"],
            doubleOptIn: false
        )
        #expect(options.makeContactOptions(date: date) == expected)
    }

    @Test
    func transactionalNoPropertiesToContactOptions() {
        let options: ThomasEmailRegistrationOption = .transactional(
            ThomasEmailRegistrationOption.Transactional(
                properties: nil
            )
        )

        let expected = EmailRegistrationOptions.options(
            transactionalOptedIn: nil,
            properties: nil,
            doubleOptIn: false
        )
        #expect(options.makeContactOptions(date: date) == expected)
    }

    @Test
    func doubleOptInToContactOptions() throws {
        let options: ThomasEmailRegistrationOption = .doubleOptIn(
            ThomasEmailRegistrationOption.DoubleOptIn(
                properties: try AirshipJSON.wrap(["cool": "prop"])
            )
        )

        let expected = EmailRegistrationOptions.options(properties: ["cool": "prop"], doubleOptIn: true)
        #expect(options.makeContactOptions(date: date) == expected)
    }

    @Test
    func doubleOptInNoPropertiesToContactOptions() {
        let options: ThomasEmailRegistrationOption = .doubleOptIn(
            ThomasEmailRegistrationOption.DoubleOptIn(
                properties: nil
            )
        )

        let expected = EmailRegistrationOptions.options(properties: nil, doubleOptIn: true)
        #expect(options.makeContactOptions(date: date) == expected)
    }

}
