/* Copyright Airship and Contributors */

#if !os(tvOS)

import WebKit
import Foundation

@available(tvOS, unavailable)
@objc(UAWebView)
public class WebView : WKWebView {
    required init?(coder: NSCoder) {
        // An initial frame for initialization must be set, but it will be overridden
        // below by the autolayout constraints set in interface builder.
        let frame = UIScreen.main.bounds
        let myConfiguration = WKWebViewConfiguration()

        super.init(frame: frame, configuration: myConfiguration)

        // Apply constraints from interface builder.
        translatesAutoresizingMaskIntoConstraints = false
    }

    @discardableResult
    public override func load(_ request: URLRequest) -> WKNavigation? {
        guard Utils.connectionType() != ConnectionType.none else {
            // If we have no connection, modify the request object to prefer the most agressive cache policy
            var modifiedRequest = request
            modifiedRequest.cachePolicy = .returnCacheDataElseLoad
            return super.load(modifiedRequest)
        }

        return super.load(request)
    }
}
#endif
