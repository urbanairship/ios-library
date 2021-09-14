/* Copyright Airship and Contributors */

/**
 * - Note: For internal use only. :nodoc:
 */
@objc(UAChannelCreateResponse)
public class ChannelCreateResponse : HTTPResponse {

    @objc
    public let channelID: String?

    @objc
    public init(status: Int, channelID: String?) {
        self.channelID = channelID
        super.init(status: status)
    }
}
