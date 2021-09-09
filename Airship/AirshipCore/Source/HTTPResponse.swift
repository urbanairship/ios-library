/* Copyright Airship and Contributors */

@objc(UAHTTPResponse)
public class HTTPResponse: NSObject {
    @objc
    public let status: Int

    public override var debugDescription: String {
        return "HTTPResponse(status=\(status))"
    }

    @objc
    public override var description : String {
        return self.debugDescription
    }

    @objc
    public init(status: Int) {
        self.status = status
    }

    @objc
    public var isSuccess : Bool {
        get {
            return status >= 200 && status <= 299
        }
    }

    @objc
    public var isClientError : Bool {
        get {
            return status >= 400 && status <= 499
        }
    }

    @objc
    public var isServerError : Bool {
        get {
            return status >= 500 && status <= 599
        }
    }
}
