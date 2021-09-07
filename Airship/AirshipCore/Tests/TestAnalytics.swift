import Foundation

@testable
import AirshipCore

@objc(UATestAnalytics)
public class TestAnalytics : NSObject, AnalyticsProtocol, UAComponent {
    public var isComponentEnabled: Bool = true
    
    @objc
    public var events: [UAEvent] = []
    
    @objc
    public var conversionSendID: String?
    
    @objc
    public var conversionPushMetadata: String?
    
    @objc
    public var sessionID: String?
    
    public var eventConsumer: UAAnalyticsEventConsumerProtocol?
    
    public func addEvent(_ event: UAEvent) {
        events.append(event)
    }
    
    public func associateDeviceIdentifiers(_ associatedIdentifiers: UAAssociatedIdentifiers) {
    }
    
    public func currentAssociatedDeviceIdentifiers() -> UAAssociatedIdentifiers {
        return UAAssociatedIdentifiers()
    }
    
    public func trackScreen(_ screen: String?) {
        
    }
    
    public func scheduleUpload() {
    }
    
    public func registerSDKExtension(_ ext: SDKExtension, version: String) {
    }
    
    public func launched(fromNotification notification: [AnyHashable : Any]) {
    }
    
    
    
}
