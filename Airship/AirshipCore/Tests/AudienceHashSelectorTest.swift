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
            bucket: AudienceHashSelector.Bucket(min: 4647, max: 11280)
        )

        // match = 11279
        XCTAssertTrue(experiment.evaluate(channelID: "match", contactID: "not used"))
        // not a match = 4646
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
            bucket: AudienceHashSelector.Bucket(min: 4647, max: 11280)
        )

        // match = 11279
        XCTAssertTrue(experiment.evaluate(channelID: "not used", contactID: "match"))
        // not a match = 4646
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
            bucket: AudienceHashSelector.Bucket(min: 4647, max: 11280)
        )

        // match = 11279
        XCTAssertTrue(experiment.evaluate(channelID: "not used", contactID: "match"))
        // not a match = 4646
        XCTAssertTrue(experiment.evaluate(channelID: "not used", contactID: "not a match"))
    }
}
