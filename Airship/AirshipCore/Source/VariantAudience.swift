/* Copyright Airship and Contributors */

import Foundation

/// Makes an in-app schedule one arm of an Experiment Groups variant experiment.
///
/// Every schedule sharing an experiment is given an identical `audienceHash`, so hashing it
/// resolves the same bucket for a given device no matter which sibling schedule asks. Reuses
/// `AudienceHashSelector`'s hash/bucket primitives rather than a second hashing mechanism.
///
/// - Note: For internal use only. :nodoc:
@_spi(AirshipInternal)
public struct VariantAudience: Codable, Sendable, Equatable {

    /// Where a device's resolved hash bucket falls within the experiment.
    @frozen
    public enum Outcome: String, Sendable, Equatable, Codable {
        /// The bucket falls in this schedule's own arm: proceed with a normal execution.
        case matched

        /// The bucket falls in the experiment's shared no-message arm.
        case holdout

        /// The bucket falls in neither this arm nor the holdout arm — some sibling
        /// schedule's arm owns it.
        case variantMiss = "variant_miss"

        /// True for `holdout` and `variantMiss` — the outcomes where this schedule does not
        /// display.
        public var isDisplaySkipped: Bool {
            self != .matched
        }
    }

    private let hash: AudienceHashSelector.Hash
    private let audienceSubset: AudienceHashSelector.Bucket
    private let holdoutSubset: AudienceHashSelector.Bucket?

    enum CodingKeys: String, CodingKey {
        case hash = "audience_hash"
        case audienceSubset = "audience_subset"
        case holdoutSubset = "holdout_subset"
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.hash = try container.decode(AudienceHashSelector.Hash.self, forKey: .hash)
        self.audienceSubset = try container.decode(AudienceHashSelector.Bucket.self, forKey: .audienceSubset)
        self.holdoutSubset = try container.decodeIfPresent(AudienceHashSelector.Bucket.self, forKey: .holdoutSubset)
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(hash, forKey: .hash)
        try container.encode(audienceSubset, forKey: .audienceSubset)
        try container.encodeIfPresent(holdoutSubset, forKey: .holdoutSubset)
    }

    /// Resolves this schedule's outcome within its variant experiment.
    /// - Parameters:
    ///   - channelID: The device's channel ID.
    ///   - contactID: The device's contact ID.
    /// - Returns: The resolved ``Outcome``.
    public func resolve(channelID: String, contactID: String) -> Outcome {
        if AudienceHashSelector(hash: hash, bucket: audienceSubset)
            .evaluate(channelID: channelID, contactID: contactID) {
            return .matched
        }

        if let holdoutSubset,
           AudienceHashSelector(hash: hash, bucket: holdoutSubset)
            .evaluate(channelID: channelID, contactID: contactID) {
            return .holdout
        }

        return .variantMiss
    }
}
