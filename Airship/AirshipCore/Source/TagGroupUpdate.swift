import Foundation

// NOTE: For internal use only. :nodoc:
@objc(UATagGroupUpdateType)
public enum TagGroupUpdateType : Int, Codable {
    case add
    case remove
    case set
}

// NOTE: For internal use only. :nodoc:
@objc(UATagGroupUpdate)
public class TagGroupUpdate : NSObject, Codable {
    
    @objc
    public let group: String
    
    @objc
    public let tags: [String]
    
    @objc
    public let type: TagGroupUpdateType
    
    @objc
    public init(group: String, tags: [String], type: TagGroupUpdateType) {
        self.group = group
        self.tags = tags
        self.type = type
    }
    
    static func == (lhs: TagGroupUpdate, rhs: TagGroupUpdate) -> Bool {
        return
            lhs.tags == rhs.tags &&
            lhs.group == rhs.group &&
            lhs.type == rhs.type
    }
    
    public override func isEqual(_ object: Any?) -> Bool {
        if let object = object as? TagGroupUpdate {
            return self == object
        } else {
            return false
        }
    }
    
    public override var hash : Int {
        var result = 1
        result = 31 &* result &+ self.tags.hashValue
        result = 31 &* result &+ self.group.hashValue
        result = 31 &* result &+ self.type.rawValue
        return result
    }
    
    
    public override var description: String {
        return "TagUpdate(tags=\(self.tags), group=\(self.group), type=\(self.type))"
    }
}
