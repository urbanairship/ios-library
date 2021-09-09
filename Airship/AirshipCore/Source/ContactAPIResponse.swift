/* Copyright Airship and Contributors */

// NOTE: For internal use only. :nodoc:
class ContactAPIResponse : HTTPResponse {
    let contactID: String?

    let isAnonymous: Bool?

    init(status: Int, contactID: String?, isAnonymous: Bool?) {
        self.contactID = contactID
        self.isAnonymous = isAnonymous
        super.init(status: status)
    }
}
