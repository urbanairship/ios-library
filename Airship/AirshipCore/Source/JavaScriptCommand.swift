/* Copyright Airship and Contributors */

#if !os(tvOS) && !os(watchOS)



// Model object for holding data associated with JS delegate calls
public struct JavaScriptCommand: Sendable, CustomDebugStringConvertible {

    // A name, derived from the host passed in the delegate call URL.
    public let name: String?

    // The argument strings passed in the call.
    public let arguments: [String]

    // The query options passed in the call.
    public let options: [String: [String]]

    // The original URL that initiated the call.
    public let url: URL

    public init(url: URL) {
        self.url = url

        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        var encodedUrlPath = components?.percentEncodedPath
        if let path = encodedUrlPath, path.hasPrefix("/") {
            encodedUrlPath = String(path.dropFirst())
        }

        // Put the arguments into an array
        // NOTE: we special case an empty array as componentsSeparatedByString
        // returns an array with a copy of the input in the first position when passed
        // a string without any delimiters
        var args: [String] = []
        if let encodedUrlPath = encodedUrlPath, !encodedUrlPath.isEmpty {
            let encodedArgs = encodedUrlPath.components(separatedBy: "/")

            args = encodedArgs.compactMap { encoded in
                encoded.removingPercentEncoding
            }
        }

        self.arguments = args

        var options: [String: [String]] = [:]
        components?.queryItems?.forEach { item in
            if (options[item.name] == nil) {
                options[item.name] = []
            }

            options[item.name]?.append(item.value ?? "")
        }

        self.options = options
        self.name = url.host
    }

    public var debugDescription: String {
        "JavaScriptCommand{name=\(String(describing: name)), options=\(options)}, arguments=\(arguments), url=\(url)})"
    }
}

#endif
