/* Copyright Airship and Contributors */

import XCTest
@testable import AirshipCore
final class AudienceHashSelectorTest: XCTestCase {

    func testCodable() throws {
        let json: String = """
        {
            "audience_hash": {
                "hash_prefix": "e66a2371-fecf-41de-9238-cb6c28a86cec:",
                "num_hash_buckets": 16384,
                "hash_identifier": "contact",
                "hash_algorithm": "farm_hash",
                "hash_seed": 100,
                "hash_identifier_overrides": {
                    "foo": "bar"
                }
            },
            "audience_subset": {
                "min_hash_bucket": 10,
                "max_hash_bucket": 100
            }
        }
        """

        let decoded: AudienceHashSelector = try JSONDecoder().decode(
            AudienceHashSelector.self,
            from: json.data(using: .utf8)!
        )

        let expected = AudienceHashSelector(
            hash: AudienceHashSelector.Hash(
                prefix: "e66a2371-fecf-41de-9238-cb6c28a86cec:",
                property: .contact,
                algorithm: .farm,
                seed: 100,
                numberOfBuckets: 16384,
                overrides: [ "foo": "bar" ]
            ),
            bucket: AudienceHashSelector.Bucket(min: 10, max: 100)
        )

        XCTAssertEqual(decoded, expected)

        let encoded = String(data: try JSONEncoder().encode(decoded), encoding: .utf8)
        XCTAssertEqual(try AirshipJSON.from(json: json), try AirshipJSON.from(json: encoded))
    }
    
    func testCodableWithSticky() throws {
        let json: String = """
        {
          "audience_hash": {
            "hash_prefix": "e66a2371-fecf-41de-9238-cb6c28a86cec:",
            "num_hash_buckets": 16384,
            "hash_identifier": "contact",
            "hash_algorithm": "farm_hash",
            "hash_seed": 100,
            "hash_identifier_overrides": {
              "foo": "bar"
            }
          },
          "audience_subset": {
            "min_hash_bucket": 10,
            "max_hash_bucket": 100
          },
          "sticky": {
            "id": "test-id",
            "reporting_metadata": "test",
            "last_access_ttl": 123
          }
        }
        """

        let decoded: AudienceHashSelector = try JSONDecoder().decode(
            AudienceHashSelector.self,
            from: json.data(using: .utf8)!
        )

        let expected = AudienceHashSelector(
            hash: AudienceHashSelector.Hash(
                prefix: "e66a2371-fecf-41de-9238-cb6c28a86cec:",
                property: .contact,
                algorithm: .farm,
                seed: 100,
                numberOfBuckets: 16384,
                overrides: [ "foo": "bar" ]
            ),
            bucket: AudienceHashSelector.Bucket(min: 10, max: 100),
            sticky: AudienceHashSelector.Sticky(
                id: "test-id",
                reportingMetadata: "test",
                lastAccessTTL: 0.123
            )
        )

        XCTAssertEqual(decoded, expected)

        let encoded = String(data: try JSONEncoder().encode(decoded), encoding: .utf8)
        XCTAssertEqual(try AirshipJSON.from(json: json), try AirshipJSON.from(json: encoded))
    }

    func testBoundaries() throws {
        let selectorGenerator: (UInt64, UInt64) throws -> AudienceHashSelector = { min, max in
            let json = """
                {
                    "audience_hash":{
                       "hash_prefix":"686f2c15-cf8c-47a6-ae9f-e749fc792a9d:",
                       "num_hash_buckets":16384,
                       "hash_identifier":"contact",
                       "hash_algorithm":"farm_hash"
                    },
                    "audience_subset":{
                       "min_hash_bucket":\(min),
                       "max_hash_bucket":\(max)
                    }
                 }
            """

            return try JSONDecoder().decode(
                AudienceHashSelector.self,
                from: json.data(using: .utf8)!
            )
        }


        // contactId = 9908
        XCTAssertTrue(
            try selectorGenerator(9908, 9908)
                .evaluate(
                    channelID: "",
                    contactID: "contactId"
                )
        )

        XCTAssertTrue(
            try selectorGenerator(9907, 9908)
                .evaluate(
                    channelID: "",
                    contactID: "contactId"
                )
        )

        XCTAssertTrue(
            try selectorGenerator(9908, 9909)
                .evaluate(
                    channelID: "",
                    contactID: "contactId"
                )
        )

        XCTAssertFalse(
            try selectorGenerator(9907, 9907)
                .evaluate(
                    channelID: "",
                    contactID: "contactId"
                )
        )

        XCTAssertFalse(
            try selectorGenerator(9909, 9909)
                .evaluate(
                    channelID: "",
                    contactID: "contactId"
                )
        )
    }

    func testEvaluateChannel() throws {
        let experiment = AudienceHashSelector(
            hash: AudienceHashSelector.Hash(
                prefix: "e66a2371-fecf-41de-9238-cb6c28a86cec:",
                property: .channel,
                algorithm: .farm,
                seed: 100,
                numberOfBuckets: 16384,
                overrides: nil
            ),
            bucket: AudienceHashSelector.Bucket(min: 11600, max: 13000)
        )

        // match = 12443
        XCTAssertTrue(experiment.evaluate(channelID: "match", contactID: "not used"))
        // not a match = 11599
        XCTAssertFalse(experiment.evaluate(channelID: "not a match", contactID: "not used"))
    }

    func testEvaluateContact() throws {
        let experiment = AudienceHashSelector(
            hash: AudienceHashSelector.Hash(
                prefix: "e66a2371-fecf-41de-9238-cb6c28a86cec:",
                property: .contact,
                algorithm: .farm,
                seed: 100,
                numberOfBuckets: 16384,
                overrides: nil
            ),
            bucket: AudienceHashSelector.Bucket(min: 11600, max: 13000)
        )


        // match = 12443
        XCTAssertTrue(experiment.evaluate(channelID: "not used", contactID: "match"))
        // not a match = 11599
        XCTAssertFalse(experiment.evaluate(channelID: "not used", contactID: "not a match"))
    }

    func testEvaluateOverrides() throws {
        let experiment = AudienceHashSelector(
            hash: AudienceHashSelector.Hash(
                prefix: "e66a2371-fecf-41de-9238-cb6c28a86cec:",
                property: .contact,
                algorithm: .farm,
                seed: 100,
                numberOfBuckets: 16384,
                overrides: [
                    "not a match" : "match"
                ]
            ),
            bucket: AudienceHashSelector.Bucket(min: 11600, max: 13000)
        )

        // match = 12443
        XCTAssertTrue(experiment.evaluate(channelID: "not used", contactID: "match"))
        // not a match = 11599
        XCTAssertTrue(experiment.evaluate(channelID: "not used", contactID: "not a match"))
    }
}
