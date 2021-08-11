import Foundation

/**
 * Used to migrate data to TagGroupUpdate in contact and channels.
 */
@objc(UATagGroupsMutation)
class TagGroupsMutation : NSObject, NSSecureCoding {
    static let codableAddKey = "add"
    static let codableRemoveKey = "remove"
    static let codableSetKey = "set"

    public static var supportsSecureCoding: Bool = true
    
    
    private let adds: [String : Set<String>]?
    private let removes: [String : Set<String>]?
    private let sets: [String : Set<String>]?
    
    public init(adds: [String: Set<String>]?, removes: [String: Set<String>]?, sets: [String: Set<String>]?) {
        self.adds = adds
        self.removes  = removes
        self.sets = sets
        super.init()
    }

    public var tagGroupUpdates: [TagGroupUpdate] {
        get {
            var updates: [TagGroupUpdate] = []
            
            self.adds?.forEach {
                updates.append(TagGroupUpdate(group: $0.key, tags: Array($0.value), type: .add))
            }
            
            self.removes?.forEach {
                updates.append(TagGroupUpdate(group: $0.key, tags: Array($0.value), type: .remove))
            }
            
            self.sets?.forEach {
                updates.append(TagGroupUpdate(group: $0.key, tags: Array($0.value), type: .set))
            }
            
            return updates;
        }
    }

    func encode(with coder: NSCoder) {
        coder.encode(self.adds, forKey: TagGroupsMutation.codableAddKey)
        coder.encode(self.removes, forKey: TagGroupsMutation.codableRemoveKey)
        coder.encode(self.sets, forKey: TagGroupsMutation.codableSetKey)
    }
    
    required init?(coder: NSCoder) {
        self.adds = coder.decodeObject(of: NSDictionary.self, forKey: TagGroupsMutation.codableAddKey) as?  [String : Set<String>]
        self.removes = coder.decodeObject(of: NSDictionary.self, forKey: TagGroupsMutation.codableRemoveKey) as?  [String : Set<String>]
        self.sets = coder.decodeObject(of: NSDictionary.self, forKey: TagGroupsMutation.codableSetKey) as?  [String : Set<String>]
    }
}
