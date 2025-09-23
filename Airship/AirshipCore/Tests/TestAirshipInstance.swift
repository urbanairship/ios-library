/* Copyright Airship and Contributors */

import Foundation

@testable
import AirshipCore

final class TestAirshipInstance: AirshipInstance, @unchecked Sendable {
    var inputValidator: any AirshipInputValidation.Validator {
        fatalError("Not implemented")
    }

    var _permissionsManager: DefaultAirshipPermissionsManager?
    var permissionsManager: any AirshipPermissionsManager {
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

    private var _actionRegistry: (any AirshipActionRegistry)?
    public var actionRegistry: any AirshipActionRegistry {
        get {
            return _actionRegistry!
        }
        set {
            _actionRegistry = newValue
        }
    }
    
    private var _channelCapture: (any AirshipChannelCapture)?
    public var channelCapture: any AirshipChannelCapture {
        get {
            return _channelCapture!
        }
        set {
            _channelCapture = newValue
        }
    }

    private var _urlAllowList: (any AirshipURLAllowList)?
    public var urlAllowList: any AirshipURLAllowList {
        get {
            return _urlAllowList!
        }
        set {
            _urlAllowList = newValue
        }
    }

    private var _localeManager: (any AirshipLocaleManager)?
    public var localeManager: AirshipLocaleManager {
        get {
            return _localeManager!
        }
        set {
            _localeManager = newValue
        }
    }

    private var _privacyManager: (any InternalAirshipPrivacyManager)?
    public var privacyManager: any InternalAirshipPrivacyManager {
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
    public var onDeepLink: (@MainActor @Sendable (URL) async -> Void)?

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
        _permissionsManager = DefaultAirshipPermissionsManager()
    }
}
