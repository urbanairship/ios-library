/* Copyright Airship and Contributors */

import XCTest

@testable
import AirshipCore

final class ExperimentTest: XCTestCase {

    var encoder: JSONEncoder {
        let encoder = JSONEncoder()
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS"
        encoder.dateEncodingStrategy = .formatted(dateFormatter)
        return encoder
    }

    var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS"
        decoder.dateDecodingStrategy = .formatted(dateFormatter)
        return decoder
    }


    func testCodable() throws {
        let json: String =  """
        {
           "created" : "2023-07-10T18:10:46.203",
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
           "last_updated" : "2023-07-11T16:06:49.003",
        }
        """

        let decoded: Experiment = try self.decoder.decode(
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
                .init(messageTypePredicate: try! .fromJson(json: ["value": ["equals": "transactional"]]), campaignsPredicate: nil)
            ],
            timeCriteria: .init(start: Date(milliseconds: 1689012595000), end: Date(milliseconds: 1689091608000))
        )

        let encoded = String(data: try encoder.encode(decoded), encoding: .utf8)
        XCTAssertEqual(try AirshipJSON.from(json: json), try AirshipJSON.from(json: encoded))
        XCTAssertEqual(expected, decoded)
    }
    
    func testCodableWithCompoundAudience() throws {
        let json: String =  """
        {
          "created": "2023-07-10T18:10:46.203",
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
          "last_updated": "2023-07-11T16:06:49.003"
        }
        """

        let decoded: Experiment = try self.decoder.decode(
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
                .init(messageTypePredicate: try! .fromJson(json: ["value": ["equals": "transactional"]]), campaignsPredicate: nil)
            ],
            timeCriteria: .init(start: Date(milliseconds: 1689012595000), end: Date(milliseconds: 1689091608000))
        )

        let encoded = String(data: try encoder.encode(decoded), encoding: .utf8)
        XCTAssertEqual(try AirshipJSON.from(json: json), try AirshipJSON.from(json: encoded))
        XCTAssertEqual(expected, decoded)
    }
}
