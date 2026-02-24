/* Copyright Airship and Contributors */

import XCTest

@testable
import AirshipCore

@testable
import AirshipFeatureFlags

final class FeatureFlagInfoTest: XCTestCase {
    
    func testDecode() throws {
        let json = """
        {
          "flag_id": "27f26d85-0550-4df5-85f0-7022fa7a5925",
          "created": "2023-07-10T18:10:46.203",
          "last_updated": "2023-07-10T18:10:46.203",
          "platforms": [
            "web"
          ],
          "flag": {
            "name": "cool_flag",
            "type": "static",
            "reporting_metadata": {
              "flag_id": "27f26d85-0550-4df5-85f0-7022fa7a5925"
            },
            "audience_selector": {
              "app_version": {
                "value": {
                  "version_matches": "1.6.0+"
                }
              },
              "hash": {
                "audience_hash": {
                  "hash_prefix": "27f26d85-0550-4df5-85f0-7022fa7a5925:",
                  "num_hash_buckets": 16384,
                  "hash_identifier": "contact",
                  "hash_algorithm": "farm_hash"
                },
                "audience_subset": {
                  "min_hash_bucket": 0,
                  "max_hash_bucket": 1637
                }
              }
            },
            "control": {
              "reporting_metadata": "superseded",
              "type": "flag"
            },
            "variables": {
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
          }
        }
        """

        let decoded: FeatureFlagInfo = try JSONDecoder().decode(
            FeatureFlagInfo.self,
            from: json.data(using: .utf8)!
        )

        let expected = FeatureFlagInfo(
            id: "27f26d85-0550-4df5-85f0-7022fa7a5925",
            created: AirshipDateFormatter.date(fromISOString: "2023-07-10T18:10:46.203")!,
            lastUpdated: AirshipDateFormatter.date(fromISOString: "2023-07-10T18:10:46.203")!,
            name: "cool_flag",
            reportingMetadata: try! AirshipJSON.wrap(["flag_id":"27f26d85-0550-4df5-85f0-7022fa7a5925"]),
            audienceSelector: DeviceAudienceSelector(
                versionPredicate: JSONPredicate(
                    jsonMatcher: JSONMatcher(
                        valueMatcher: .matcherWithVersionConstraint("1.6.0+")!
                    )
                ),
                hashSelector: AudienceHashSelector(
                    hash: .init(
                        prefix: "27f26d85-0550-4df5-85f0-7022fa7a5925:",
                        property: .contact,
                        algorithm: .farm,
                        seed: nil,
                        numberOfBuckets: 16384,
                        overrides: nil
                    ),
                    bucket: .init(min: 0, max: 1637)
                )
            ),
            flagPayload: .staticPayload(
                FeatureFlagPayload.StaticInfo(
                    variables: .variant(
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
                )
            ),
            controlOptions: ControlOptions(
                compoundAudience: nil,
                reportingMetadata: "superseded",
                controlType: .flag
            )
        )

        XCTAssertEqual(decoded, expected)
    }

    func testDecodeWithCompoundAudience() throws {
        let json = """
        {
          "flag_id": "27f26d85-0550-4df5-85f0-7022fa7a5925",
          "created": "2023-07-10T18:10:46.203",
          "last_updated": "2023-07-10T18:10:46.203",
          "platforms": [
            "web"
          ],
          "flag": {
            "name": "cool_flag",
            "type": "static",
            "reporting_metadata": {
              "flag_id": "27f26d85-0550-4df5-85f0-7022fa7a5925"
            },
            "audience_selector": {
              "app_version": {
                "value": {
                  "version_matches": "1.6.0+"
                }
              },
              "hash": {
                "audience_hash": {
                  "hash_prefix": "27f26d85-0550-4df5-85f0-7022fa7a5925:",
                  "num_hash_buckets": 16384,
                  "hash_identifier": "contact",
                  "hash_algorithm": "farm_hash"
                },
                "audience_subset": {
                  "min_hash_bucket": 0,
                  "max_hash_bucket": 1637
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
            "control": {
              "audience_selector": {
                "app_version": {
                  "value": {
                    "version_matches": "1.6.0+"
                  }
                }
              },
              "reporting_metadata": "superseded",
              "type": "flag",
              "compound_audience": {
                "selector": {
                  "type": "atomic",
                  "audience": {
                    "new_user": true
                  }
                }
              }
            },
            "variables": {
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
          }
        }
        """

        let decoded: FeatureFlagInfo = try JSONDecoder().decode(
            FeatureFlagInfo.self,
            from: json.data(using: .utf8)!
        )

        let expected = FeatureFlagInfo(
            id: "27f26d85-0550-4df5-85f0-7022fa7a5925",
            created: AirshipDateFormatter.date(fromISOString: "2023-07-10T18:10:46.203")!,
            lastUpdated: AirshipDateFormatter.date(fromISOString: "2023-07-10T18:10:46.203")!,
            name: "cool_flag",
            reportingMetadata: try! AirshipJSON.wrap(["flag_id":"27f26d85-0550-4df5-85f0-7022fa7a5925"]),
            audienceSelector: DeviceAudienceSelector(
                versionPredicate: JSONPredicate(
                    jsonMatcher: JSONMatcher(
                        valueMatcher: .matcherWithVersionConstraint("1.6.0+")!
                    )
                ),
                hashSelector: AudienceHashSelector(
                    hash: .init(
                        prefix: "27f26d85-0550-4df5-85f0-7022fa7a5925:",
                        property: .contact,
                        algorithm: .farm,
                        seed: nil,
                        numberOfBuckets: 16384,
                        overrides: nil
                    ),
                    bucket: .init(min: 0, max: 1637)
                )
            ),
            compoundAudience: .init(selector: .atomic(DeviceAudienceSelector(newUser: true))),
            flagPayload: .staticPayload(
                FeatureFlagPayload.StaticInfo(
                    variables: .variant(
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
                )
            ),
            controlOptions: ControlOptions(
                compoundAudience: .init(selector: .atomic(DeviceAudienceSelector(newUser: true))),
                reportingMetadata: "superseded",
                controlType: .flag
            )
        )

        XCTAssertEqual(decoded, expected)
    }

    func testDecodeControl() throws {
        let json = """
        {
           "compound_audience":{
              "selector":{
                 "type":"atomic",
                 "audience":{
                    "app_version":{
                       "value":{
                          "version_matches":"1.6.0+"
                       }
                    }
                 }
              }
           },
           "reporting_metadata":"superseded",
           "type":"variables",
           "data":"variables_override"
        }
        """
        
        let decoded = try JSONDecoder().decode(
            ControlOptions.self,
            from: json.data(using: .utf8)!
        )
        
        let expected = ControlOptions(
            compoundAudience: FeatureFlagCompoundAudience(
                selector: .atomic(
                    .init(
                        versionPredicate: JSONPredicate(
                            jsonMatcher: JSONMatcher(
                                valueMatcher: .matcherWithVersionConstraint("1.6.0+")!
                            )
                        )
                    )
                )
            ),
            reportingMetadata: "superseded",
            controlType: .variables(.string("variables_override"))
        )

        XCTAssertEqual(expected, decoded)
    }
}

