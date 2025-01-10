/* Copyright Airship and Contributors */

public import Foundation

#if canImport(AirshipCore)
import AirshipCore
#endif

@objc
public final class UAAssociatedIdentifiers: NSObject {

    var identifiers: [String: String]
    
    init(identifiers: [String: String]) {
        self.identifiers = identifiers
    }
    
    @objc
    public func set(identifier: String?, key: String) {
        self.identifiers[key] = identifier
    }
    
}
