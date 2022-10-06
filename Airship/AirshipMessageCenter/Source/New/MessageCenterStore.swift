/* Copyright Airship and Contributors */

import Foundation

actor MessageCenterStore {
//    var user: MessageCenterUser? {
//        get {
//            return nil
//        }
//        set {
//
//        }
//    }
    
    var messages: [MessageCenterMessage] {
        get {
            return []
        }
        set {

        }
    }

    var unreadCount: Int {
        get {
          return 0
        }
    }

    func message(forID: String) -> MessageCenterMessage? {
        return nil
    }

    func markRead(messageIDs: [String]) {

    }

    func delete(messageIDs: [String]) {

    }
    
    func updateLastModified(lastModified: Any?, username: String) {
    }
    
    func getLastModified(username: String) -> String? {
        return ""
    }
}
