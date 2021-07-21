import Foundation

// NOTE: For internal use only. :nodoc:
enum TagGroupUpdateType : String, Codable {
    case add
    case remove
    case set
}

// NOTE: For internal use only. :nodoc:
struct TagGroupUpdate : Codable {
    let group: String
    let tags: [String]
    let type: TagGroupUpdateType
}
