/* Copyright Airship and Contributors */

import Foundation
import Testing

@testable @_spi(AirshipInternal) import AirshipBasement
@testable @_spi(AirshipInternal) import AirshipSceneRenderer

struct ThomasFormRegistrationOverridesTest {

    private let state: AirshipJSON = [
        "promo": true,
        "locale": "en-US",
        "count": 3
    ]

    private func decode(_ json: String) throws -> ThomasFormRegistrationOverrides {
        try JSONDecoder().decode(
            ThomasFormRegistrationOverrides.self,
            from: json.data(using: .utf8)!
        )
    }

    @Test
    func decodesPatchValues() throws {
        let overrides = try decode("""
        {
          "email": [
            {
              "input_id": "email",
              "when_state_matches": { "scope": ["promo"], "value": { "equals": true } },
              "registration": {
                "type": "commercial",
                "commercial_opted_in": { "type": "value", "value": true },
                "open_tracking_opted_in": { "type": "state", "scope": ["promo"] },
                "click_tracking_opted_in": { "type": "value", "value": false },
                "properties": {
                  "set": { "locale": { "type": "state", "scope": ["locale"] } },
                  "remove": ["old"]
                }
              }
            }
          ]
        }
        """)

        let override = try #require(overrides.email?.first)
        #expect(override.inputID == "email")
        #expect(override.registration.type == .commercial)
        #expect(override.registration.commercialOptedIn == .value(true))
        #expect(override.registration.openTrackingOptedIn == .state(scope: ["promo"]))
        #expect(override.registration.clickTrackingOptedIn == .value(false))
        #expect(override.registration.properties?.set?["locale"] == .state(scope: ["locale"]))
        #expect(override.registration.properties?.remove == ["old"])
    }

    @Test
    func noTypeAnywhereResolvesToNil() throws {
        let overrides = try decode("""
        {
          "email": [
            {
              "when_state_matches": { "scope": ["promo"], "value": { "equals": true } },
              "registration": { "commercial_opted_in": { "type": "value", "value": true } }
            }
          ]
        }
        """)

        #expect(overrides.resolveEmail(inputID: "email", options: nil, state: state) == nil)
    }

    @Test
    func patchSuppliesTypeForInputWithoutOptions() throws {
        let overrides = try decode("""
        {
          "email": [
            {
              "when_state_matches": { "scope": ["promo"], "value": { "equals": true } },
              "registration": { "type": "commercial" }
            }
          ]
        }
        """)

        let resolved = overrides.resolveEmail(inputID: "email", options: nil, state: state)
        #expect(resolved == .commercial(.init(optedIn: false)))
    }

    @Test
    func unmatchedPredicateAndOtherInputAreSkipped() throws {
        let overrides = try decode("""
        {
          "email": [
            {
              "when_state_matches": { "scope": ["promo"], "value": { "equals": false } },
              "registration": { "type": "commercial" }
            },
            {
              "input_id": "other",
              "when_state_matches": { "scope": ["promo"], "value": { "equals": true } },
              "registration": { "type": "double_opt_in" }
            }
          ]
        }
        """)

        let options: ThomasEmailRegistrationOption = .transactional(.init())
        let resolved = overrides.resolveEmail(inputID: "email", options: options, state: state)
        #expect(resolved == options)
    }

    @Test
    func patchesApplyInListOrder() throws {
        let overrides = try decode("""
        {
          "email": [
            {
              "when_state_matches": { "scope": ["promo"], "value": { "equals": true } },
              "registration": {
                "type": "commercial",
                "commercial_opted_in": { "type": "value", "value": true }
              }
            },
            {
              "input_id": "email",
              "when_state_matches": { "scope": ["promo"], "value": { "equals": true } },
              "registration": { "type": "double_opt_in" }
            }
          ]
        }
        """)

        let resolved = overrides.resolveEmail(
            inputID: "email",
            options: .transactional(.init(properties: ["a": "b"])),
            state: state
        )
        #expect(resolved == .doubleOptIn(.init(properties: ["a": "b"])))
    }

    @Test
    func commercialValueSurvivesTypeRoundTrip() throws {
        let overrides = try decode("""
        {
          "email": [
            {
              "when_state_matches": { "scope": ["promo"], "value": { "equals": true } },
              "registration": { "type": "transactional" }
            },
            {
              "when_state_matches": { "scope": ["promo"], "value": { "equals": true } },
              "registration": { "type": "commercial" }
            }
          ]
        }
        """)

        let resolved = overrides.resolveEmail(
            inputID: "email",
            options: .commercial(.init(optedIn: true)),
            state: state
        )
        #expect(resolved == .commercial(.init(optedIn: true)))
    }

    @Test
    func stateValuesAreReadWithoutCoercion() throws {
        let overrides = try decode("""
        {
          "email": [
            {
              "when_state_matches": { "scope": ["promo"], "value": { "equals": true } },
              "registration": {
                "commercial_opted_in": { "type": "state", "scope": ["count"] },
                "open_tracking_opted_in": { "type": "state", "scope": ["promo"] },
                "properties": {
                  "set": {
                    "locale": { "type": "state", "scope": ["locale"] },
                    "missing": { "type": "state", "scope": ["nope"] }
                  }
                }
              }
            }
          ]
        }
        """)

        let resolved = overrides.resolveEmail(
            inputID: "email",
            options: .commercial(.init(optedIn: true, properties: ["missing": "kept"])),
            state: state
        )
        #expect(
            resolved == .commercial(
                .init(
                    optedIn: true,
                    properties: ["missing": "kept", "locale": "en-US"],
                    openTrackingOptedIn: true
                )
            )
        )
    }

    @Test
    func mistypedOrNullLiteralsAreIgnored() throws {
        let overrides = try decode("""
        {
          "email": [
            {
              "when_state_matches": { "scope": ["promo"], "value": { "equals": true } },
              "registration": {
                "commercial_opted_in": { "type": "value", "value": "yes" },
                "open_tracking_opted_in": { "type": "value", "value": null },
                "properties": {
                  "set": { "a": { "type": "value", "value": null } }
                }
              }
            }
          ]
        }
        """)

        let options: ThomasEmailRegistrationOption = .commercial(
            .init(optedIn: true, properties: ["a": "kept"], openTrackingOptedIn: false)
        )
        let resolved = overrides.resolveEmail(inputID: "email", options: options, state: state)
        #expect(resolved == options)
    }

    @Test
    func propertiesRemoveRunsBeforeSet() throws {
        let overrides = try decode("""
        {
          "email": [
            {
              "when_state_matches": { "scope": ["promo"], "value": { "equals": true } },
              "registration": {
                "properties": {
                  "set": { "a": { "type": "value", "value": "new" } },
                  "remove": ["a", "b", "absent"]
                }
              }
            }
          ]
        }
        """)

        let resolved = overrides.resolveEmail(
            inputID: "email",
            options: .doubleOptIn(.init(properties: ["a": "old", "b": "gone", "c": "kept"])),
            state: state
        )
        #expect(resolved == .doubleOptIn(.init(properties: ["a": "new", "c": "kept"])))
    }
}
