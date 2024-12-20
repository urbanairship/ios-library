/* Copyright Airship and Contributors */

import XCTest

@testable
import AirshipCore

@testable
import AirshipFeatureFlags

final class FeatureFlagVariablesTest: XCTestCase {

    func testCodableVariant() throws {
        let json = """
              {
                "type": "variant",
                "variants": [
                  {
                    "id": "dda26cb5-e40b-4bc8-abb1-eb88240f7fd7",
                    "reporting_metadata": {
                      "flag_id": "27f26d85-0550-4df5-85f0-7022fa7a5925",
                      "variant_id": "dda26cb5-e40b-4bc8-abb1-eb88240f7fd7"
                    },
                    "audience_selector": {
                      "hash": {
                        "audience_hash": {
                          "hash_prefix": "686f2c15-cf8c-47a6-ae9f-e749fc792a9d:",
                          "num_hash_buckets": 100,
                          "hash_identifier": "contact",
                          "hash_algorithm": "farm_hash"
                        },
                        "audience_subset": {
                          "min_hash_bucket": 0,
                          "max_hash_bucket": 9
                        }
                      }
                    },
                    "compound_audience": {
                      "selector": {
                        "type": "atomic",
                        "audience": {
                          "new_user": true
                        }
                      }
                    },
                    "data": {
                      "arbitrary_key_1": "some_value",
                      "arbitrary_key_2": "some_other_value"
                    }
                  },
                  {
                    "id": "15422380-ce8f-49df-a7b1-9755b88ec0ef",
                    "reporting_metadata": {
                      "flag_id": "27f26d85-0550-4df5-85f0-7022fa7a5925",
                      "variant_id": "15422380-ce8f-49df-a7b1-9755b88ec0ef"
                    },
                    "audience_selector": {
                      "hash": {
                        "audience_hash": {
                          "hash_prefix": "686f2c15-cf8c-47a6-ae9f-e749fc792a9d:",
                          "num_hash_buckets": 100,
                          "hash_identifier": "contact",
                          "hash_algorithm": "farm_hash"
                        },
                        "audience_subset": {
                          "min_hash_bucket": 0,
                          "max_hash_bucket": 19
                        }
                      }
                    },
                    "data": {
                      "arbitrary_key_1": "different_value",
                      "arbitrary_key_2": "different_other_value"
                    }
                  },
                  {
                    "id": "40e08a3d-8901-40fc-a01a-e6c263bec895",
                    "reporting_metadata": {
                      "flag_id": "27f26d85-0550-4df5-85f0-7022fa7a5925",
                      "variant_id": "40e08a3d-8901-40fc-a01a-e6c263bec895"
                    },
                    "data": {
                      "arbitrary_key_1": "some default value",
                      "arbitrary_key_2": "some other default value"
                    }
                  }
                ]
              }
        """

        let decoded: FeatureFlagVariables = try JSONDecoder().decode(
            FeatureFlagVariables.self,
            from: json.data(using: .utf8)!
        )

        let expected = FeatureFlagVariables.variant(
            [
                .init(
                    id: "dda26cb5-e40b-4bc8-abb1-eb88240f7fd7",
                    audienceSelector: DeviceAudienceSelector(
                        hashSelector: AudienceHashSelector(
                            hash: .init(
                                prefix: "686f2c15-cf8c-47a6-ae9f-e749fc792a9d:",
                                property: .contact,
                                algorithm: .farm,
                                seed: nil,
                                numberOfBuckets: 100,
                                overrides: nil
                            ),
                            bucket: .init(min: 0, max: 9)
                        )
                    ),
                    compoundAudience: .init(selector: .atomic(DeviceAudienceSelector(newUser: true))),
                    reportingMetadata: try AirshipJSON.wrap(
                        [
                            "flag_id": "27f26d85-0550-4df5-85f0-7022fa7a5925",
                            "variant_id": "dda26cb5-e40b-4bc8-abb1-eb88240f7fd7"
                        ]
                    ),
                    data: try AirshipJSON.wrap(
                        [
                            "arbitrary_key_1": "some_value",
                            "arbitrary_key_2": "some_other_value"
                        ]
                    )
                ),
                .init(
                    id: "15422380-ce8f-49df-a7b1-9755b88ec0ef",
                    audienceSelector: DeviceAudienceSelector(
                        hashSelector: AudienceHashSelector(
                            hash: .init(
                                prefix: "686f2c15-cf8c-47a6-ae9f-e749fc792a9d:",
                                property: .contact,
                                algorithm: .farm,
                                seed: nil,
                                numberOfBuckets: 100,
                                overrides: nil
                            ),
                            bucket: .init(min: 0, max: 19)
                        )
                    ),
                    compoundAudience: nil,
                    reportingMetadata: try AirshipJSON.wrap(
                        [
                            "flag_id": "27f26d85-0550-4df5-85f0-7022fa7a5925",
                            "variant_id": "15422380-ce8f-49df-a7b1-9755b88ec0ef"
                        ]
                    ),
                    data: try AirshipJSON.wrap(
                        [
                            "arbitrary_key_1": "different_value",
                            "arbitrary_key_2": "different_other_value"
                        ]
                    )
                ),
                .init(
                    id: "40e08a3d-8901-40fc-a01a-e6c263bec895",
                    audienceSelector: nil,
                    compoundAudience: nil,
                    reportingMetadata: try AirshipJSON.wrap(
                        [
                            "flag_id": "27f26d85-0550-4df5-85f0-7022fa7a5925",
                            "variant_id": "40e08a3d-8901-40fc-a01a-e6c263bec895"
                        ]
                    ),
                    data: try AirshipJSON.wrap(
                        [
                            "arbitrary_key_1": "some default value",
                            "arbitrary_key_2": "some other default value"
                        ]
                    )
                )
            ]
        )

        XCTAssertEqual(decoded, expected)

        let encoded = String(data: try JSONEncoder().encode(decoded), encoding: .utf8)
        XCTAssertEqual(try AirshipJSON.from(json: json), try AirshipJSON.from(json: encoded))
    }

    func testCodableFixed() throws {
        let json = """
          {
             "type":"fixed",
              "data":{
                  "arbitrary_key_1":"some_value",
                  "arbitrary_key_2":"some_other_value"
               }
          }
        """

        let decoded: FeatureFlagVariables = try JSONDecoder().decode(
            FeatureFlagVariables.self,
            from: json.data(using: .utf8)!
        )

        let expected = FeatureFlagVariables.fixed(
            try AirshipJSON.wrap(
                [
                    "arbitrary_key_1": "some_value",
                    "arbitrary_key_2": "some_other_value"
                ]
            )
        )


        XCTAssertEqual(decoded, expected)

        let encoded = String(data: try JSONEncoder().encode(decoded), encoding: .utf8)
        XCTAssertEqual(try AirshipJSON.from(json: json), try AirshipJSON.from(json: encoded))
    }

    func testCodableFixedNullData() throws {
        let json = """
          {
             "type":"fixed"
          }
        """

        let decoded: FeatureFlagVariables = try JSONDecoder().decode(
            FeatureFlagVariables.self,
            from: json.data(using: .utf8)!
        )

        let expected = FeatureFlagVariables.fixed(nil)

        XCTAssertEqual(decoded, expected)

        let encoded = String(data: try JSONEncoder().encode(decoded), encoding: .utf8)
        XCTAssertEqual(try AirshipJSON.from(json: json), try AirshipJSON.from(json: encoded))
    }
}

