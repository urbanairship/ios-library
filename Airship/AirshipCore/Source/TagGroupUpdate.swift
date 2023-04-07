import Foundation

// NOTE: For internal use only. :nodoc:
enum TagGroupUpdateType: Int, Codable, Equatable, Hashable, Sendable {
    case add
    case remove
    case set
}

// NOTE: For internal use only. :nodoc:
struct TagGroupUpdate: Codable, Sendable, Equatable, Hashable {
    let group: String
    let tags: [String]
    let type: TagGroupUpdateType
}
