/* Copyright Airship and Contributors */

#if !os(tvOS)

import Foundation

@objc (UAJavaScriptEnvironmentProtocol)
public protocol JavaScriptEnvironmentProtocol {
    
    /// Builds the script that can be injected into a web view.
    @objc
    func build() -> String
    
}

/**
 * The JavaScript environment builder that is used by the native bridge.
 */
@objc(UAJavaScriptEnvironment)
public class JavaScriptEnvironment : NSObject, JavaScriptEnvironmentProtocol {
    
    private var extensions : Set<String> =  {
        return defaultExtensions()
    }()
    
    private class func defaultExtensions() -> Set<String> {
        var defaults: Set<String> = []
        defaults.insert(JavaScriptEnvironment.stringGetter("getDeviceModel", UIDevice.current.model))
        let contact : ContactProtocol = Airship.requireComponent(ofType: ContactProtocol.self)
        if (contact.namedUserID != nil) {
            defaults.insert(JavaScriptEnvironment.stringGetter("getNamedUser", contact.namedUserID!))
        }
        let channel: ChannelProtocol =  Airship.requireComponent(ofType: ChannelProtocol.self)
        if (channel.identifier != nil) {
            defaults.insert(JavaScriptEnvironment.stringGetter("getChannelId", channel.identifier!))
        }       
        defaults.insert(JavaScriptEnvironment.stringGetter("getAppKey", Airship.shared.config.appKey))
        return defaults
    }
    
    @objc(addStringGetter:value:)
    public func add(_ stringGetter: String, _ value: String?) {
        guard let value = value else {
            let ext = String(format: "_UAirship.%@ = function() {return null;};", stringGetter)
            self.extensions.insert(ext)
            return
        }
        self.extensions.insert(JavaScriptEnvironment.stringGetter(stringGetter, value))
    }
    
    @objc(addNumberGetter:value:)
    public func add(_ numberGetter: String, _ value: NSNumber?) {
        let ext = String(format: "_UAirship.%@ = function() {return %@;};", numberGetter, value ?? -1)
        self.extensions.insert(ext)
    }
    
    @objc(addDictionaryGetter:value:)
    public func add(_ dictionaryGetter: String, _ value: NSDictionary?) {
        let ext: String
        guard let value = value, JSONSerialization.isValidJSONObject(value) else {
            ext = String(format: "_UAirship.%@ = function() {return null;};", dictionaryGetter)
            self.extensions.insert(ext)
            return
        }
    
        let jsonData: Data
        
        do {
            jsonData = try JSONSerialization.data(withJSONObject: value, options: .prettyPrinted)
        }
        catch {
            ext = String(format: "_UAirship.%@ = function() {return null;};", dictionaryGetter)
            self.extensions.insert(ext)
            return
        }
        
        guard let jsonString = String.init(data: jsonData, encoding: .utf8) else {
            return
        }
        
        ext = String(format: "_UAirship.%@ = function() {return %@;};", dictionaryGetter, jsonString)
        self.extensions.insert(ext)
    }
    
    /**
     * Builds the script that can be injected into a web view.
     * - returns: The  script.
     */
    @objc(build)
    public func build() -> String {
        var js = "var _UAirship = {};"
        for ext in self.extensions {
            js = js.appending(ext)
        }
        
        guard let path =  AirshipCoreResources.bundle.path(forResource: "UANativeBridge", ofType: "") else {
            AirshipLogger.impError("UANativeBridge resource file is missing.")
            return js
        }
        
        let bridge: String
        
        do {
            bridge = try String(contentsOfFile: path, encoding: .utf8)
        }
        catch {
            AirshipLogger.impError("UANativeBridge resource file is missing.")
            return js
        }
        
        return js.appending(bridge)
    }
    
    private class func stringGetter(_ name: String, _ value: String) -> String {
        let encodedValue = value.addingPercentEncoding(withAllowedCharacters: CharacterSet.urlHostAllowed)
        return String(format: "_UAirship.%@ = function() {return decodeURIComponent(\"%@\");};", name, encodedValue ?? "")
    }
    
}

#endif
