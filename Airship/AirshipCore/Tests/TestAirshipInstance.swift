/* Copyright Airship and Contributors */

import Foundation

@testable
import AirshipCore

final class TestAirshipInstance: AirshipInstanceProtocol, @unchecked Sendable {
    var inputValidator: any AirshipCore.AirshipInputValidation.Validator {
        fatalError("Not implemented")
    }

    var _permissionsManager: AirshipPermissionsManager?
    var permissionsManager: AirshipPermissionsManager {
        return _permissionsManager!
    }

    public let preferenceDataStore: AirshipCore.PreferenceDataStore = PreferenceDataStore(appKey: UUID().uuidString)

    private var _config: RuntimeConfig?
    public var config: RuntimeConfig {
        get {
            return _config!
        }
        set {
            _config = newValue
        }
    }

    private var _actionRegistry: ActionRegistry?
    public var actionRegistry: ActionRegistry {
        get {
            return _actionRegistry!
        }
        set {
            _actionRegistry = newValue
        }
    }
    
    private var _channelCapture: ChannelCapture?
    public var channelCapture: ChannelCapture {
        get {
            return _channelCapture!
        }
        set {
            _channelCapture = newValue
        }
    }

    private var _urlAllowList: URLAllowListProtocol?
    public var urlAllowList: URLAllowListProtocol {
        get {
            return _urlAllowList!
        }
        set {
            _urlAllowList = newValue
        }
    }

    private var _localeManager: AirshipLocaleManager?
    public var localeManager: AirshipLocaleManager {
        get {
            return _localeManager!
        }
        set {
            _localeManager = newValue
        }
    }

    private var _privacyManager: AirshipPrivacyManager?
    public var privacyManager: AirshipPrivacyManager {
        get {
            return _privacyManager!
        }
        set {
            _privacyManager = newValue
        }
    }

    public var javaScriptCommandDelegate: JavaScriptCommandDelegate?

    public var deepLinkDelegate: DeepLinkDelegate?

    @MainActor
    public var deepLinkHandler: (@MainActor @Sendable (URL) async -> Void)?

    public var components: [AirshipComponent] = []

    private var componentMap: [String: AirshipComponent] = [:]

    public func component<E>(ofType componentType: E.Type) -> E? {
        let key = "Type:\(componentType)"
        if componentMap[key] == nil {
            self.componentMap[key] = self.components.first { ($0 as? E) != nil }
        }

        return componentMap[key] as? E
    }

    public func makeShared() {
        Airship._shared = Airship(instance: self)
    }

    public class func clearShared() {
        Airship._shared = nil
    }

    public func airshipReady() {
    }
    
    @MainActor
    init() {
        _permissionsManager = AirshipPermissionsManager()
    }
}
