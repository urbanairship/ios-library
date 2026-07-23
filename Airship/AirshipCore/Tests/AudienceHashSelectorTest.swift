/* Copyright Airship and Contributors */

import Testing
@_spi(AirshipInternal) @testable import AirshipCore
import Foundation

@Suite struct AudienceHashSelectorTest {

    @Test
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

        #expect(decoded == expected)

        let encoded = String(data: try JSONEncoder().encode(decoded), encoding: .utf8)
        #expect(try AirshipJSON.from(json: json) == AirshipJSON.from(json: encoded))
    }
    
    @Test
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

        #expect(decoded == expected)

        let encoded = String(data: try JSONEncoder().encode(decoded), encoding: .utf8)
        #expect(try AirshipJSON.from(json: json) == AirshipJSON.from(json: encoded))
    }

    @Test
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
        #expect(
            try selectorGenerator(9908, 9908)
                .evaluate(
                    channelID: "",
                    contactID: "contactId"
                )
        )

        #expect(
            try selectorGenerator(9907, 9908)
                .evaluate(
                    channelID: "",
                    contactID: "contactId"
                )
        )

        #expect(
            try selectorGenerator(9908, 9909)
                .evaluate(
                    channelID: "",
                    contactID: "contactId"
                )
        )

        #expect(
            !(try selectorGenerator(9907, 9907)
                .evaluate(
                    channelID: "",
                    contactID: "contactId"
                ))
        )

        #expect(
            !(try selectorGenerator(9909, 9909)
                .evaluate(
                    channelID: "",
                    contactID: "contactId"
                ))
        )
    }

    @Test
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
        #expect(experiment.evaluate(channelID: "match", contactID: "not used"))
        // not a match = 11599
        #expect(!experiment.evaluate(channelID: "not a match", contactID: "not used"))
    }

    @Test
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
        #expect(experiment.evaluate(channelID: "not used", contactID: "match"))
        // not a match = 11599
        #expect(!experiment.evaluate(channelID: "not used", contactID: "not a match"))
    }

    @Test
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
        #expect(experiment.evaluate(channelID: "not used", contactID: "match"))
        // not a match = 11599
        #expect(experiment.evaluate(channelID: "not used", contactID: "not a match"))
    }

    // MARK: - Audience subset overrides

    /// Hash params where contactID "match" resolves to bucket 12443.
    private static func makeHash(property: AudienceHashSelector.Hash.Identifier = .contact) -> AudienceHashSelector.Hash {
        AudienceHashSelector.Hash(
            prefix: "e66a2371-fecf-41de-9238-cb6c28a86cec:",
            property: property,
            algorithm: .farm,
            seed: 100,
            numberOfBuckets: 16384,
            overrides: nil
        )
    }

    private static func date(_ seconds: TimeInterval) -> Date {
        Date(timeIntervalSince1970: seconds)
    }

    private static func schedule(start: TimeInterval?, end: TimeInterval?) -> AirshipTimeCriteria {
        AirshipTimeCriteria(
            start: start.map { date($0) },
            end: end.map { date($0) }
        )
    }

    @Test
    func testStaticOverrideActivates() throws {
        // Base bucket matches nobody; override subset contains 12443.
        let selector = AudienceHashSelector(
            hash: Self.makeHash(),
            bucket: AudienceHashSelector.Bucket(min: 0, max: 0),
            overrides: [
                .static(
                    schedule: Self.schedule(start: 1000, end: 2000),
                    subset: AudienceHashSelector.Bucket(min: 12000, max: 13000)
                )
            ]
        )

        // Inside the window -> override subset used -> match.
        #expect(selector.evaluate(channelID: "n/a", contactID: "match", date: Self.date(1500)))

        // Outside the window -> falls back to base bucket (0...0) -> no match.
        #expect(!selector.evaluate(channelID: "n/a", contactID: "match", date: Self.date(3000)))
        // Before the window as well.
        #expect(!selector.evaluate(channelID: "n/a", contactID: "match", date: Self.date(500)))
    }

    @Test
    func testLinearRampInterpolation() throws {
        let override: AudienceHashSelector.AudienceSubsetOverride = .linearRamp(
            schedule: Self.schedule(start: 1000, end: 2000),
            subsetStart: AudienceHashSelector.Bucket(min: 100, max: 10000),
            subsetEnd: AudienceHashSelector.Bucket(min: 200, max: 20000)
        )

        // Start
        #expect(override.resolveBucket(date: Self.date(1000)) == AudienceHashSelector.Bucket(min: 100, max: 10000))
        // Midpoint
        #expect(override.resolveBucket(date: Self.date(1500)) == AudienceHashSelector.Bucket(min: 150, max: 15000))
        // End (interpolation clamps to end subset)
        #expect(override.resolveBucket(date: Self.date(2000)) == AudienceHashSelector.Bucket(min: 200, max: 20000))
        // Clamped before start
        #expect(override.resolveBucket(date: Self.date(0)) == AudienceHashSelector.Bucket(min: 100, max: 10000))
        // Clamped after end
        #expect(override.resolveBucket(date: Self.date(9999)) == AudienceHashSelector.Bucket(min: 200, max: 20000))
    }

    @Test
    func testLinearRampInvertedSubsetDoesNotUnderflow() throws {
        // subsetStart > subsetEnd. Casting to Double before subtraction avoids unsigned underflow.
        let override: AudienceHashSelector.AudienceSubsetOverride = .linearRamp(
            schedule: Self.schedule(start: 1000, end: 2000),
            subsetStart: AudienceHashSelector.Bucket(min: 0, max: 20000),
            subsetEnd: AudienceHashSelector.Bucket(min: 0, max: 10000)
        )

        #expect(override.resolveBucket(date: Self.date(1000)) == AudienceHashSelector.Bucket(min: 0, max: 20000))
        #expect(override.resolveBucket(date: Self.date(1500)) == AudienceHashSelector.Bucket(min: 0, max: 15000))
        #expect(override.resolveBucket(date: Self.date(2000)) == AudienceHashSelector.Bucket(min: 0, max: 10000))
    }

    @Test
    func testLinearRampActivationViaEvaluate() throws {
        // At start, max=12000 excludes 12443; ramps up to include it by midpoint.
        let selector = AudienceHashSelector(
            hash: Self.makeHash(),
            bucket: AudienceHashSelector.Bucket(min: 0, max: 0),
            overrides: [
                .linearRamp(
                    schedule: Self.schedule(start: 1000, end: 2000),
                    subsetStart: AudienceHashSelector.Bucket(min: 0, max: 12000),
                    subsetEnd: AudienceHashSelector.Bucket(min: 0, max: 13000)
                )
            ]
        )

        // t = 0 -> max 12000 -> 12443 excluded.
        #expect(!selector.evaluate(channelID: "n/a", contactID: "match", date: Self.date(1000)))
        // t = 0.5 -> max 12500 -> 12443 included.
        #expect(selector.evaluate(channelID: "n/a", contactID: "match", date: Self.date(1500)))
    }

    @Test
    func testFirstMatchingOverrideWins() throws {
        // Two overlapping active overrides. The first (non-matching) one should win.
        let selector = AudienceHashSelector(
            hash: Self.makeHash(),
            bucket: AudienceHashSelector.Bucket(min: 12000, max: 13000),
            overrides: [
                .static(
                    schedule: Self.schedule(start: 1000, end: 2000),
                    subset: AudienceHashSelector.Bucket(min: 0, max: 0)
                ),
                .static(
                    schedule: Self.schedule(start: 1000, end: 2000),
                    subset: AudienceHashSelector.Bucket(min: 12000, max: 13000)
                )
            ]
        )

        // First override subset (0...0) is used -> 12443 excluded -> no match.
        #expect(!selector.evaluate(channelID: "n/a", contactID: "match", date: Self.date(1500)))
    }

    @Test
    func testFirstActiveOverrideWinsSkippingInactive() throws {
        // First override is inactive at the eval date; the second (active) one is used.
        let selector = AudienceHashSelector(
            hash: Self.makeHash(),
            bucket: AudienceHashSelector.Bucket(min: 0, max: 0),
            overrides: [
                .static(
                    schedule: Self.schedule(start: 0, end: 1000),
                    subset: AudienceHashSelector.Bucket(min: 0, max: 0)
                ),
                .static(
                    schedule: Self.schedule(start: 1000, end: 2000),
                    subset: AudienceHashSelector.Bucket(min: 12000, max: 13000)
                )
            ]
        )

        // Second override subset (12000...13000) contains 12443 -> match.
        #expect(selector.evaluate(channelID: "n/a", contactID: "match", date: Self.date(1500)))
    }

    @Test
    func testFallbackToBaseWhenNoOverrideActive() throws {
        let selector = AudienceHashSelector(
            hash: Self.makeHash(),
            bucket: AudienceHashSelector.Bucket(min: 11600, max: 13000),
            overrides: [
                .static(
                    schedule: Self.schedule(start: 1000, end: 2000),
                    subset: AudienceHashSelector.Bucket(min: 0, max: 0)
                )
            ]
        )

        // Evaluated outside any override window -> base bucket (11600...13000) contains 12443.
        #expect(selector.evaluate(channelID: "n/a", contactID: "match", date: Self.date(5000)))
    }

    @Test
    func testMissingOverridesUnchangedBehavior() throws {
        let selector = AudienceHashSelector(
            hash: Self.makeHash(),
            bucket: AudienceHashSelector.Bucket(min: 11600, max: 13000)
        )

        #expect(selector.overrides == nil)
        // Behavior unchanged regardless of date.
        #expect(selector.evaluate(channelID: "n/a", contactID: "match", date: Self.date(1500)))
        #expect(!selector.evaluate(channelID: "n/a", contactID: "not a match", date: Self.date(1500)))
    }

    @Test
    func testCodableWithOverrides() throws {
        let json: String = """
        {
          "audience_hash": {
            "hash_prefix": "e66a2371-fecf-41de-9238-cb6c28a86cec:",
            "num_hash_buckets": 16384,
            "hash_identifier": "contact",
            "hash_algorithm": "farm_hash",
            "hash_seed": 100
          },
          "audience_subset": {
            "min_hash_bucket": 10,
            "max_hash_bucket": 100
          },
          "audience_subset_overrides": [
            {
              "type": "linear_ramp",
              "start_timestamp": 1000000,
              "end_timestamp": 2000000,
              "audience_subset_start": {
                "min_hash_bucket": 0,
                "max_hash_bucket": 100
              },
              "audience_subset_end": {
                "min_hash_bucket": 0,
                "max_hash_bucket": 1000
              }
            },
            {
              "type": "static",
              "start_timestamp": 2000000,
              "audience_subset": {
                "min_hash_bucket": 0,
                "max_hash_bucket": 1000
              }
            }
          ]
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
                overrides: nil
            ),
            bucket: AudienceHashSelector.Bucket(min: 10, max: 100),
            overrides: [
                .linearRamp(
                    schedule: Self.schedule(start: 1000, end: 2000),
                    subsetStart: AudienceHashSelector.Bucket(min: 0, max: 100),
                    subsetEnd: AudienceHashSelector.Bucket(min: 0, max: 1000)
                ),
                .static(
                    schedule: Self.schedule(start: 2000, end: nil),
                    subset: AudienceHashSelector.Bucket(min: 0, max: 1000)
                )
            ]
        )

        #expect(decoded == expected)

        let encoded = String(data: try JSONEncoder().encode(decoded), encoding: .utf8)
        #expect(try AirshipJSON.from(json: json) == AirshipJSON.from(json: encoded))
    }

    @Test
    func testLinearRampRequiresBothTimestamps() throws {
        let json: String = """
        {
          "audience_hash": {
            "hash_prefix": "e66a2371-fecf-41de-9238-cb6c28a86cec:",
            "num_hash_buckets": 16384,
            "hash_identifier": "contact",
            "hash_algorithm": "farm_hash",
            "hash_seed": 100
          },
          "audience_subset": {
            "min_hash_bucket": 10,
            "max_hash_bucket": 100
          },
          "audience_subset_overrides": [
            {
              "type": "linear_ramp",
              "start_timestamp": 1000000,
              "audience_subset_start": {
                "min_hash_bucket": 0,
                "max_hash_bucket": 100
              },
              "audience_subset_end": {
                "min_hash_bucket": 0,
                "max_hash_bucket": 1000
              }
            }
          ]
        }
        """

        #expect(throws: DecodingError.self) {
            _ = try JSONDecoder().decode(
                AudienceHashSelector.self,
                from: json.data(using: .utf8)!
            )
        }
    }
}
