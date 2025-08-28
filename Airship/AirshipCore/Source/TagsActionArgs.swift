

struct TagsActionsArgs: Decodable {
    let channel: [String: [String]]?
    let namedUser: [String: [String]]?
    let device: [String]?

    enum CodingKeys: String, CodingKey {
        case channel = "channel"
        case namedUser = "named_user"
        case device = "device"
    }
}

