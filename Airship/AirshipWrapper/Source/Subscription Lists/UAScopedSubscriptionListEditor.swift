import Foundation
import AirshipCore

@objc
public class UAScopedSubscriptionListEditor: NSObject {
    
    var editor: ScopedSubscriptionListEditor?
    
    /**
     * Subscribes to a list.
     * - Parameters:
     *   - subscriptionListID: The subscription list identifier.
     *   - scope: Defines the channel types that the change applies to.
     */
    @objc(subscribe:scope:)
    public func subscribe(_ subscriptionListID: String, scope: UAChannelScope) {
        self.editor?.subscribe(subscriptionListID, scope: scope.toChannelScope)
    }

    /**
     * Unsubscribes from a list.
     * - Parameters:
     *   - subscriptionListID: The subscription list identifier.
     *   - scope: Defines the channel types that the change applies to.
     */
    @objc(unsubscribe:scope:)
    public func unsubscribe(_ subscriptionListID: String, scope: UAChannelScope) {
        self.editor?.unsubscribe(subscriptionListID, scope: scope.toChannelScope)
    }

    /**
     * Applies subscription list changes.
     */
    @objc
    public func apply() {
        self.editor?.apply()
    }
}
    
@objc
/// Channel scope.
public enum UAChannelScope: Int, Sendable, Equatable {
    /**
     * App channels - amazon, android, iOS
     */
    case app

    /**
     * Web channels
     */
    case web

    /**
     * Email channels
     */
    case email

    /**
     * SMS channels
     */
    case sms

    var toChannelScope: ChannelScope {
        return switch(self) {
        case .app: .app
        case .web: .web
        case .email: .email
        case .sms: .sms
        }
    }
}

extension ChannelScope {
    var toUAChannelScope: UAChannelScope {
        return switch(self) {
        case .app: .app
        case .web: .web
        case .email: .email
        case .sms: .sms
#if canImport(AirshipCore)
        default:
                .app
#endif
        }
    }
}

