/* Copyright Airship and Contributors */

#if !os(tvOS) && !os(watchOS)

import Foundation

@objc(UAJavaScriptEnvironmentProtocol)
public protocol JavaScriptEnvironmentProtocol: Sendable {


    /// Adds a string getter to the Airship JavaScript environment.
    /// - Parameter getter: The getter's name.
    /// - Parameter string: The getter's value.
    @objc(addStringGetter:value:)
    func add(_ getter: String, string: String?)

    /// Adds a number getter to the Airship JavaScript environment.
    /// - Parameter getter: The getter's name.
    /// - Parameter number: The getter's value.
    @objc(addNumberGetter:value:)
    func add(_ getter: String, number: NSNumber?)

    /// Adds a dictionary getter to the Airship JavaScript environment.
    /// - Parameter getter: The getter's name.
    /// - Parameter dictionary: The getter's value.
    @objc(addDictionaryGetter:value:)
    func add(_ getter: String, dictionary: [AnyHashable: Any]?)

    /**
     * Builds the script that can be injected into a web view.
     * - Returns: The script.
     */
    @objc
    func build() async -> String
}


/// The JavaScript environment builder that is used by the native bridge.
@objc(UAJavaScriptEnvironment)
public final class JavaScriptEnvironment: NSObject, JavaScriptEnvironmentProtocol, @unchecked Sendable {

    private var extensions: [String] = []
    private var lock: AirshipLock = AirshipLock()
    private let channel: () -> AirshipChannelProtocol
    private let contact: () -> AirshipContactProtocol

    @objc
    public override convenience init() {
        self.init(
            channel: Airship.componentSupplier(),
            contact: Airship.componentSupplier()
        )
    }

    init(
        channel: @escaping () -> AirshipChannelProtocol,
        contact: @escaping () -> AirshipContactProtocol
    ) {
        self.channel = channel
        self.contact = contact
    }

    @objc(addStringGetter:value:)
    public func add(_ getter: String, string: String?) {
        self.addExtension(
            makeGetter(name: getter, string: string)
        )
    }

    @objc(addNumberGetter:value:)
    public func add(_ getter: String, number: NSNumber?) {
        self.addExtension(
            makeGetter(name: getter, number: number)
        )
    }

    @objc(addDictionaryGetter:value:)
    public func add(_ getter: String, dictionary: [AnyHashable: Any]?) {
        self.addExtension(
            makeGetter(name: getter, dictionary: dictionary)
        )
    }

    @objc
    public func build() async -> String {
        var js = "var _UAirship = {};"
        var extensions: [String] = await self.makeDefaultExtensions()
        lock.sync {
            extensions += self.extensions
        }

        for ext in extensions {
            js = js.appending(ext)
        }

        guard
            let path = AirshipCoreResources.bundle.path(
                forResource: "UANativeBridge",
                ofType: ""
            )
        else {
            AirshipLogger.impError(
                "UANativeBridge resource file is missing."
            )
            return js
        }

        let bridge: String

        do {
            bridge = try String(contentsOfFile: path, encoding: .utf8)
        } catch {
            AirshipLogger.impError(
                "UANativeBridge resource file is missing."
            )
            return js
        }

        return js.appending(bridge)
    }

    private func makeDefaultExtensions() async -> [String] {
        return await [
            makeGetter(
                name: "getDeviceModel",
                string: UIDevice.current.model
            ),

            makeGetter(
                name: "getNamedUser",
                string: self.contact().namedUserID
            ),

            makeGetter(
                name: "getChannelId",
                string: self.channel().identifier
            ),

            makeGetter(
                name: "getAppKey",
                string: Airship.config.appKey
            )
        ]
    }

    private func addExtension(_ ext: String) {
        lock.sync {
            self.extensions.append(ext)
        }
    }

    private func makeGetter(
        name: String,
        string: String?
    ) -> String {
        guard let value = string else {
            return String(
                format: "_UAirship.%@ = function() {return null;};",
                name
            )
        }

        let encodedValue = value.addingPercentEncoding(
            withAllowedCharacters: CharacterSet.urlHostAllowed
        )
        return String(
            format:
                "_UAirship.%@ = function() {return decodeURIComponent(\"%@\");};",
            name,
            encodedValue ?? ""
        )
    }

    private func makeGetter(
        name: String,
        number: NSNumber?
    ) -> String {
        String(
            format: "_UAirship.%@ = function() {return %@;};",
            name,
            number ?? -1
        )
    }

    private func makeGetter(name: String, dictionary: [AnyHashable: Any]?) -> String {
        guard let value = dictionary,
              JSONSerialization.isValidJSONObject(value),
              let jsonData: Data = try? JSONSerialization.data(
                  withJSONObject: value,
                  options: []
              ),
              let jsonString = String.init(data: jsonData, encoding: .utf8)
        else {
            return String(
                format: "_UAirship.%@ = function() {return null;};",
                name
            )
        }

        return String(
            format: "_UAirship.%@ = function() {return %@;};",
            name,
            jsonString
        )
    }
}

#endif
