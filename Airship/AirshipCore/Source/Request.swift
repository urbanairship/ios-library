/* Copyright Airship and Contributors */


@objc(UARequestBuilder)
public class RequestBuilder : NSObject {
    var headers: [String : String] = [:]

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
    public func addHeaders(_ headers: [String : String]) {
        for (k, v) in headers { self.headers[k] = v }
    }
}

@objc(UARequest)
public class Request : NSObject {
    @objc
    public let method: String?
    @objc
    public let url: URL?
    @objc
    public let headers: [String : String]
    @objc
    public let body: Data?

    private init(builder: RequestBuilder) {
        method = builder.method
        url = builder.url
        var headers = builder.headers

        // Additional headers
        for (k, v) in builder.headers { headers[k] = v }

        // Basic auth
        if builder.username != nil && builder.password != nil {
            let credentials = "\(builder.username!):\(builder.password!)"
            let encodedCredentials = credentials.data(using: .utf8)
            let authoriazationValue = "Basic \(encodedCredentials?.base64EncodedString(options: []) ?? "")"
            headers["Authorization"] = authoriazationValue
        }

        if builder.body != nil {
            if builder.compressBody {
                if let gzipped = builder.body?.gzip() {
                    body = gzipped
                    headers["Content-Encoding"] = "gzip"
                } else {
                    body = builder.body
                }
            } else {
                body = builder.body
            }
        } else {
            body = nil
        }

        self.headers = headers
    }

    @objc
    public static func request(withBuilderBlock block: @escaping (_ builder: RequestBuilder) -> Void) -> Request {
        return Request(builderBlock: block);
    }

    @objc
    public convenience init(builderBlock: @escaping (_ builder: RequestBuilder) -> Void) {
        let builder = RequestBuilder()
        builderBlock(builder)
        self.init(builder: builder)
    }
}


private extension Data {
    func gzip() -> Data? {
        return UACompression.gzipData(self)
    }
}
