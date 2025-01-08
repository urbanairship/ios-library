/* Copyright Airship and Contributors */

import Foundation
#if canImport(AirshipCore)
import AirshipCore
#endif


@objc
public final class UACustomEventAccountTemplate: NSObject {

    fileprivate var template: CustomEvent.AccountTemplate

    private init(template: CustomEvent.AccountTemplate) {
        self.template = template
    }

    @objc
    public static func registered() -> UACustomEventAccountTemplate {
        self.init(template: .registered)
    }

    @objc
    public static func loggedIn() -> UACustomEventAccountTemplate {
        self.init(template: .loggedIn)
    }

    @objc
    public static func loggedOut() -> UACustomEventAccountTemplate {
        self.init(template: .loggedOut)
    }
}

@objc
public final class UACustomEventAccountProperties: NSObject {

    /// User ID.
    @objc
    public var userID: String?

    /// The event's category.
    @objc
    public var category: String?

    /// The event's type.
    @objc
    public var type: String?

    /// If the value is a lifetime value or not.
    @objc
    public var isLTV: Bool

    @objc
    public init(category: String? = nil, type: String? = nil, isLTV: Bool = false, userID: String? = nil) {
        self.category = category
        self.type = type
        self.isLTV = isLTV
        self.userID = userID
    }

    fileprivate var properties: CustomEvent.AccountProperties {
        return .init(
            category: self.category,
            type: self.type,
            isLTV: self.isLTV,
            userID: self.userID
        )
    }
}

@objc
public extension UACustomEvent {
    @objc
    convenience init(accountTemplate: UACustomEventAccountTemplate) {
        let customEvent = CustomEvent(accountTemplate: accountTemplate.template)
        self.init(event: customEvent)
    }

    @objc
    convenience init(accountTemplate: UACustomEventAccountTemplate, properties: UACustomEventAccountProperties) {
        let customEvent = CustomEvent(
            accountTemplate: accountTemplate.template,
            properties: properties.properties
        )
        self.init(event: customEvent)
    }
}


