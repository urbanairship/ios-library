/* Copyright Airship and Contributors */

import Foundation

@testable import AirshipCore

@objc(UATestAirshipInstance)
public class TestAirshipInstance: NSObject, AirshipInstanceProtocol {
    public let preferenceDataStore: AirshipCore.PreferenceDataStore = PreferenceDataStore(appKey: UUID().uuidString)

    private var _config: RuntimeConfig?
    @objc
    public var config: RuntimeConfig {
        get {
            return _config!
        }
        set {
            _config = newValue
        }
    }

    @objc
    public var permissionsManager: AirshipPermissionsManager = AirshipPermissionsManager()

    private var _actionRegistry: ActionRegistry?
    public var actionRegistry: ActionRegistry {
        get {
            return _actionRegistry!
        }
        set {
            _actionRegistry = newValue
        }
    }

    private var _applicationMetrics: ApplicationMetrics?
    public var applicationMetrics: ApplicationMetrics {
        get {
            return _applicationMetrics!
        }
        set {
            _applicationMetrics = newValue
        }
    }

    private var _channelCapture: ChannelCapture?
    @objc
    public var channelCapture: ChannelCapture {
        get {
            return _channelCapture!
        }
        set {
            _channelCapture = newValue
        }
    }

    private var _urlAllowList: URLAllowListProtocol?
    @objc
    public var urlAllowList: URLAllowListProtocol {
        get {
            return _urlAllowList!
        }
        set {
            _urlAllowList = newValue
        }
    }

    private var _localeManager: AirshipLocaleManager?
    @objc
    public var localeManager: AirshipLocaleManager {
        get {
            return _localeManager!
        }
        set {
            _localeManager = newValue
        }
    }

    private var _privacyManager: AirshipPrivacyManager?
    @objc
    public var privacyManager: AirshipPrivacyManager {
        get {
            return _privacyManager!
        }
        set {
            _privacyManager = newValue
        }
    }

    @objc
    public var javaScriptCommandDelegate: JavaScriptCommandDelegate?

    @objc
    public var deepLinkDelegate: DeepLinkDelegate?

    public var components: [AirshipComponent] = []

    private var componentMap: [String: AirshipComponent] = [:]


    public func component<E>(ofType componentType: E.Type) -> E? {
        let key = "Type:\(componentType)"
        if componentMap[key] == nil {
            self.componentMap[key] = self.components.first { ($0 as? E) != nil }
        }

        return componentMap[key] as? E
    }

    @objc
    public func makeShared() {
        Airship._shared = Airship(instance: self)
    }

    @objc
    public class func clearShared() {
        Airship._shared = nil
    }

    public func airshipReady() {
    }
}

class TestApplicationMetrics: ApplicationMetrics, @unchecked Sendable {
    
    var versionUpdated = false
    
    override var isAppVersionUpdated: Bool { return versionUpdated }
}
