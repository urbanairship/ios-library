/* Copyright Airship and Contributors */

import Foundation

/**
 * Scoped subscription lists.
 */
@objc(UAScopedSubscriptionList)
public class ScopedSubscriptionLists : NSObject {
    
    /**
     * The lists.
     */
    public let lists: [String: [ChannelScope]]
    
    /**
     * The lists.
     */
    @objc(lists)
    public var objc_lists: [String: [Int]] {
        return lists.mapValues { scopes in
            scopes.map { $0.rawValue }
        }
    }
    
    init(_ lists: [String: [ChannelScope]]) {
        self.lists = lists
        super.init()
    }
    
    public override func isEqual(_ object: Any?) -> Bool {
       return lists == (object as? ScopedSubscriptionLists)?.lists
    }
    
    public override var hash: Int {
        return lists.hashValue
    }
}
