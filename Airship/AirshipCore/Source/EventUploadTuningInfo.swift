/* Copyright Airship and Contributors */



struct EventUploadTuningInfo: Codable {
    let maxTotalStoreSizeKB: UInt?
    let maxBatchSizeKB: UInt?
    let minBatchInterval: TimeInterval?
}
