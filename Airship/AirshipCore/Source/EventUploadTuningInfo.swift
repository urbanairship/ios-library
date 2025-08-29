/* Copyright Airship and Contributors */

import Foundation

struct EventUploadTuningInfo: Codable {
    let maxTotalStoreSizeKB: UInt?
    let maxBatchSizeKB: UInt?
    let minBatchInterval: TimeInterval?
}
