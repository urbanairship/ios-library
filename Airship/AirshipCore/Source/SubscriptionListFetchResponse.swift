/* Copyright Airship and Contributors */

// NOTE: For internal use only. :nodoc:
class SubscriptionListFetchResponse : HTTPResponse {
    let listIDs: [String]?

    init(status: Int, listIDs: [String]? = nil) {
        self.listIDs = listIDs
        super.init(status: status)
    }
}


