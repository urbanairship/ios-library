/* Copyright Airship and Contributors */

/**
 * @note For internal use only. :nodoc:
 */
@objc
public class ContactAPIResponse : UAHTTPResponse {
    @objc
    public let contactID: String?

    @objc
    public let isAnonymous: Bool

    @objc
    public init(status: Int, contactID: String?, isAnonymous: Bool) {
        self.contactID = contactID
        self.isAnonymous = isAnonymous
        super.init(status: status)
    }
}
