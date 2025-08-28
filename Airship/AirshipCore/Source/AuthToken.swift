

struct AuthToken {
    let identifier: String
    let token: String
    let expiration: Date

    init(identifier: String, token: String, expiration: Date) {
        self.identifier = identifier
        self.token = token
        self.expiration = expiration
    }
}
