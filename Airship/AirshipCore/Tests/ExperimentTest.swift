/* Copyright Airship and Contributors */

import Testing

@testable
@_spi(AirshipInternal) import AirshipCore
@_spi(AirshipInternal) import AirshipBasement
import Foundation

@Suite struct ExperimentTest {

    @Test
    func testCodable() throws {
        let json: String =  """
        {
           "created" : "2023-07-10T18:10:46.203Z",
           "experiment_definition" : {
              "audience_selector" : {
                 "hash" : {
                    "audience_hash" : {
                       "hash_algorithm" : "farm_hash",
                       "hash_identifier" : "contact",
                       "hash_prefix" : "cf9b8c05-05e2-4b8e-a2a3-7ed06d99cc1c:",
                       "num_hash_buckets" : 16384
                    },
                    "audience_subset" : {
                       "max_hash_bucket" : 8192,
                       "min_hash_bucket" : 0
                    }
                 }
              },
              "experiment_type" : "holdout",
              "message_exclusions" : [
                 {
                    "message_type" : {
                       "value" : {
                          "equals" : "transactional"
                       }
                    }
                 }
              ],
              "reporting_metadata" : {
                 "experiment_id" : "cf9b8c05-05e2-4b8e-a2a3-7ed06d99cc1c"
              },
              "time_criteria" : {
                 "end_timestamp" : 1689091608000,
                 "start_timestamp" : 1689012595000
              },
              "type" : "static"
           },
           "experiment_id" : "cf9b8c05-05e2-4b8e-a2a3-7ed06d99cc1c",
           "last_updated" : "2023-07-11T16:06:49.003Z",
        }
        """

        let decoded: Experiment = try Experiment.decoder.decode(
            Experiment.self,
            from: json.data(using: .utf8)!
        )

        let expected = Experiment(
            id: "cf9b8c05-05e2-4b8e-a2a3-7ed06d99cc1c",
            lastUpdated: decoded.lastUpdated,
            created: decoded.created,
            reportingMetadata: ["experiment_id" : "cf9b8c05-05e2-4b8e-a2a3-7ed06d99cc1c"],
            audienceSelector: DeviceAudienceSelector(
                hashSelector: .init(
                    hash: .init(
                        prefix: "cf9b8c05-05e2-4b8e-a2a3-7ed06d99cc1c:",
                        property: .contact,
                        algorithm: .farm,
                        seed: nil,
                        numberOfBuckets: 16384,
                        overrides: nil),
                    bucket: .init(min: 0, max: 8192))
            ),
            exclusions: [
                .init(messageTypePredicate: try! JSONPredicate(json: ["value": ["equals": "transactional"]]), campaignsPredicate: nil)
            ],
            timeCriteria: .init(start: Date(airshipMilliseconds: 1689012595000), end: Date(airshipMilliseconds: 1689091608000))
        )

        #expect(expected == decoded)
    }

    @Test
    func testCodableWithCompoundAudience() throws {
        let json: String =  """
        {
          "created": "2023-07-10T18:10:46.203Z",
          "experiment_definition": {
            "audience_selector": {
              "hash": {
                "audience_hash": {
                  "hash_algorithm": "farm_hash",
                  "hash_identifier": "contact",
                  "hash_prefix": "cf9b8c05-05e2-4b8e-a2a3-7ed06d99cc1c:",
                  "num_hash_buckets": 16384
                },
                "audience_subset": {
                  "max_hash_bucket": 8192,
                  "min_hash_bucket": 0
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
            "experiment_type": "holdout",
            "message_exclusions": [
              {
                "message_type": {
                  "value": {
                    "equals": "transactional"
                  }
                }
              }
            ],
            "reporting_metadata": {
              "experiment_id": "cf9b8c05-05e2-4b8e-a2a3-7ed06d99cc1c"
            },
            "time_criteria": {
              "end_timestamp": 1689091608000,
              "start_timestamp": 1689012595000
            },
            "type": "static"
          },
          "experiment_id": "cf9b8c05-05e2-4b8e-a2a3-7ed06d99cc1c",
          "last_updated": "2023-07-11T16:06:49.003Z"
        }
        """

        let decoded: Experiment = try Experiment.decoder.decode(
            Experiment.self,
            from: json.data(using: .utf8)!
        )

        let expected = Experiment(
            id: "cf9b8c05-05e2-4b8e-a2a3-7ed06d99cc1c",
            lastUpdated: decoded.lastUpdated,
            created: decoded.created,
            reportingMetadata: ["experiment_id" : "cf9b8c05-05e2-4b8e-a2a3-7ed06d99cc1c"],
            audienceSelector: DeviceAudienceSelector(
                hashSelector: .init(
                    hash: .init(
                        prefix: "cf9b8c05-05e2-4b8e-a2a3-7ed06d99cc1c:",
                        property: .contact,
                        algorithm: .farm,
                        seed: nil,
                        numberOfBuckets: 16384,
                        overrides: nil),
                    bucket: .init(min: 0, max: 8192))
            ),
            compoundAudience: .init(selector: .atomic(.init(newUser: true))),
            exclusions: [
                .init(messageTypePredicate: try! JSONPredicate(json: ["value": ["equals": "transactional"]]), campaignsPredicate: nil)
            ],
            timeCriteria: .init(start: Date(airshipMilliseconds: 1689012595000), end: Date(airshipMilliseconds: 1689091608000))
        )

        #expect(expected == decoded)
    }
}
