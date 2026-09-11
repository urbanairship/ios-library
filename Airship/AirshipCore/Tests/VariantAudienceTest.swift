/* Copyright Airship and Contributors */

import Testing
@_spi(AirshipInternal) @testable import AirshipCore
import Foundation

@Suite struct VariantAudienceTest {

    // Same fixture as AudienceHashSelectorTest.testBoundaries: this prefix/contactID
    // combination resolves to bucket 9908 of 16384 via farm hash.
    private func makeVariantAudience(
        audienceSubset: (min: UInt64, max: UInt64),
        holdoutSubset: (min: UInt64, max: UInt64)? = nil,
        reportingContext: String? = nil
    ) throws -> VariantAudience {
        let holdoutJSON: String = if let holdoutSubset {
            """
            , "holdout_subset": { "min_hash_bucket": \(holdoutSubset.min), "max_hash_bucket": \(holdoutSubset.max) }
            """
        } else {
            ""
        }

        let reportingContextJSON: String = if let reportingContext {
            """
            , "reporting_context": \(reportingContext)
            """
        } else {
            ""
        }

        let json = """
        {
            "audience_hash": {
                "hash_prefix": "686f2c15-cf8c-47a6-ae9f-e749fc792a9d:",
                "num_hash_buckets": 16384,
                "hash_identifier": "contact",
                "hash_algorithm": "farm_hash"
            },
            "audience_subset": { "min_hash_bucket": \(audienceSubset.min), "max_hash_bucket": \(audienceSubset.max) }
            \(holdoutJSON)
            \(reportingContextJSON)
        }
        """

        return try JSONDecoder().decode(VariantAudience.self, from: json.data(using: .utf8)!)
    }

    @Test
    func testResolveMatched() throws {
        let variantAudience = try makeVariantAudience(audienceSubset: (9908, 9908))
        #expect(variantAudience.resolve(channelID: "", contactID: "contactId") == .matched)
    }

    @Test
    func testResolveHoldout() throws {
        let variantAudience = try makeVariantAudience(
            audienceSubset: (0, 0),
            holdoutSubset: (9908, 9908)
        )
        #expect(variantAudience.resolve(channelID: "", contactID: "contactId") == .holdout)
    }

    @Test
    func testResolveVariantMissWithHoldoutArm() throws {
        let variantAudience = try makeVariantAudience(
            audienceSubset: (0, 0),
            holdoutSubset: (1, 1)
        )
        #expect(variantAudience.resolve(channelID: "", contactID: "contactId") == .variantMiss)
    }

    @Test
    func testResolveVariantMissWithoutHoldoutArm() throws {
        let variantAudience = try makeVariantAudience(audienceSubset: (0, 0))
        #expect(variantAudience.resolve(channelID: "", contactID: "contactId") == .variantMiss)
    }

    @Test
    func testDecodesReportingContext() throws {
        let variantAudience = try makeVariantAudience(
            audienceSubset: (9908, 9908),
            reportingContext: #"{"foo": "bar"}"#
        )
        #expect(variantAudience.reportingContext == (try AirshipJSON.wrap(["foo": "bar"])))
    }

    @Test
    func testReportingContextDefaultsToNil() throws {
        let variantAudience = try makeVariantAudience(audienceSubset: (9908, 9908))
        #expect(variantAudience.reportingContext == nil)
    }

    @Test
    func testIsDisplaySkipped() {
        #expect(!VariantAudience.Outcome.matched.isDisplaySkipped)
        #expect(VariantAudience.Outcome.holdout.isDisplaySkipped)
        #expect(VariantAudience.Outcome.variantMiss.isDisplaySkipped)
    }
}
