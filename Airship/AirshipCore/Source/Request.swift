/* Copyright Airship and Contributors */

@objc(UARequestBuilder)
public class RequestBuilder: NSObject {
    var headers: [String: String] = [:]

    @objc
    public var method: String?
    @objc
    public var url: URL?
    @objc
    public var username: String?
    @objc
    public var password: String?
    @objc
    public var body: Data?
    @objc
    public var compressBody: Bool = false

    public override init() {
        super.init()
    }

    @objc
    public func setValue(_ value: String?, header: String) {
        headers[header] = value
    }

    @objc
    public func addHeaders(_ headers: [String: String]) {
        for (k, v) in headers { self.headers[k] = v }
    }
}

@objc(UARequest)
public class Request: NSObject {
    @objc
    public let method: String?
    @objc
    public let url: URL?
    @objc
    public let headers: [String: String]
    @objc
    public let body: Data?

    let username: String?
    let password: String?
    let compressBody: Bool

    private init(builder: RequestBuilder) {
        self.method = builder.method
        self.url = builder.url
        self.headers = builder.headers
        self.username = builder.username
        self.password = builder.password
        self.body = builder.body
        self.compressBody = builder.compressBody
    }

    @objc
    public static func request(
        withBuilderBlock block: @escaping (_ builder: RequestBuilder) -> Void
    ) -> Request {
        return Request(builderBlock: block)
    }

    @objc
    public convenience init(
        builderBlock: @escaping (_ builder: RequestBuilder) -> Void
    ) {
        let builder = RequestBuilder()
        builderBlock(builder)
        self.init(builder: builder)
    }
}
