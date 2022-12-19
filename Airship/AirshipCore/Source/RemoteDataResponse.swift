/* Copyright Airship and Contributors */

struct RemoteDataResponse {
    let metadata: [AnyHashable: Any]?
    let payloads: [RemoteDataPayload]?
    let lastModified: String?
}
