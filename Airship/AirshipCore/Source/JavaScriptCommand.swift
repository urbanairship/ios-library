/* Copyright Airship and Contributors */

#if !os(tvOS)

import Foundation

/**
 * Model object for holding data associated with JS delegate calls
 */
@objc(UAJavaScriptCommand)
public class JavaScriptCommand : NSObject {
    
    /**
     * A name, derived from the host passed in the delegate call URL.
     * This is typically the name of a command.
     */
    @objc
    public var name: String?
    
    /**
     * The argument strings passed in the call.
     */
    @objc
    public var arguments: [String]
    
    /**
     * The query options passed in the call.
     */
    @objc
    public var options: [AnyHashable : Any]
    
    /**
     * The original URL that initiated the call.
     */
    @objc
    public var URL: URL
    
    init(name: String?, arguments: [String], options: [AnyHashable : Any], url: URL) {
        self.name = name
        self.arguments = arguments
        self.options = options
        self.URL = url
    }
    
    @objc
    public convenience init(url: URL) {
        var args: [String] = []
        let components = NSURLComponents.init(url: url, resolvingAgainstBaseURL: false)
        var encodedUrlPath = components?.percentEncodedPath
        
        if ((encodedUrlPath != nil && encodedUrlPath!.hasPrefix("/"))) {
            let start = encodedUrlPath!.index(encodedUrlPath!.startIndex, offsetBy: 1)
            let range = start..<encodedUrlPath!.endIndex

            encodedUrlPath = String(encodedUrlPath![range])
        }
        
        // Put the arguments into an array
        // NOTE: we special case an empty array as componentsSeparatedByString
        // returns an array with a copy of the input in the first position when passed
        // a string without any delimiters
        
        if (encodedUrlPath != nil && encodedUrlPath!.count != 0) {
            let encodedArguments = encodedUrlPath!.components(separatedBy: "/")
            var decodedArguments : [String] = []
            decodedArguments.reserveCapacity(encodedArguments.count)
            
            for encodedArgument in encodedArguments {
                decodedArguments.append(encodedArgument.removingPercentEncoding ?? "")
            }
            
            args = decodedArguments
        } else {
            args = []
        }
        
        // Dictionary of options - primitive parsing, so external docs should mention the limitations
        var options: [AnyHashable : Any] = [:]
        
        
        if (components != nil && components?.queryItems != nil) {
            for queryItem in components!.queryItems! {
                let key = queryItem.name
                let value = queryItem.value ?? ""
            
                var values = options[key] as? Array<Any>
                if values == nil {
                    values = []
                }
                values?.append(value)
                options[key] = values
            }
        }
        
        self.init(name: url.host, arguments: args, options: options, url: url)
    }
    
}

#endif
