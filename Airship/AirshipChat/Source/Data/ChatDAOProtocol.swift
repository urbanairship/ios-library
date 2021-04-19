/* Copyright Airship and Contributors */

#if canImport(AirshipCore)
import AirshipCore
#elseif !COCOAPODS && canImport(Airship)
import Airship
#endif

import Foundation

/**
 * Chat data access protocol
 */
protocol ChatDAOProtocol {
    func upsertMessage(messageID: Int, requestID: String?, text: String?, createdOn: Date, direction: UInt, attachment: URL?)
    func insertPending(requestID: String, text: String?, attachment: URL?, createdOn: Date)
    func removePending(_ requestID: String)
    func fetchMessages(completionHandler: @escaping (Array<ChatMessageData>, Array<PendingChatMessageData>)->())
    func fetchPending(completionHandler: @escaping (Array<PendingChatMessageData>)->())
    func hasPendingMessages(completionHandler: @escaping (Bool)->())
}
