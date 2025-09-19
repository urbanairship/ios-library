/* Copyright Airship and Contributors */

#if !os(tvOS) && !os(watchOS)

import UIKit
import Foundation

public protocol JavaScriptEnvironmentProtocol: Sendable {


    /// Adds a string getter to the Airship JavaScript environment.
    /// - Parameter getter: The getter's name.
    /// - Parameter string: The getter's value.
    func add(_ getter: String, string: String?)

    /// Adds a number getter to the Airship JavaScript environment.
    /// - Parameter getter: The getter's name.
    /// - Parameter number: The getter's value.
    func add(_ getter: String, number: Double?)
    
    /// Adds a dictionary getter to the Airship JavaScript environment.
    /// - Parameter getter: The getter's name.
    /// - Parameter dictionary: The getter's value.
    func add(_ getter: String, dictionary: [AnyHashable: Any]?)

    /**
     * Builds the script that can be injected into a web view.
     * - Returns: The script.
     */
    func build() async -> String
}


/// The JavaScript environment builder that is used by the native bridge.
public final class JavaScriptEnvironment: JavaScriptEnvironmentProtocol, Sendable {

    private let extensions = AirshipAtomicValue([String]())
    private let channel: @Sendable () -> any AirshipChannel
    private let contact: @Sendable () -> any AirshipContact

    public convenience init() {
        self.init(
            channel: Airship.componentSupplier(),
            contact: Airship.componentSupplier()
        )
    }

    init(
        channel: @escaping @Sendable () -> any AirshipChannel,
        contact: @escaping @Sendable () -> any AirshipContact
    ) {
        self.channel = channel
        self.contact = contact
    }

    public func add(_ getter: String, string: String?) {
        self.addExtension(
            makeGetter(name: getter, string: string)
        )
    }
    
    public func add(_ getter: String, number: Double?) {
        self.addExtension(
            makeGetter(name: getter, number: number)
        )
    }

    public func add(_ getter: String, dictionary: [AnyHashable: Any]?) {
        self.addExtension(
            makeGetter(name: getter, dictionary: dictionary)
        )
    }

    public func build() async -> String {
        var js = "var _UAirship = {};"
        var extensions: [String] = await self.makeDefaultExtensions()
        extensions += self.extensions.value

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
                string: Airship.config.appCredentials.appKey
            )
        ]
    }

    private func addExtension(_ ext: String) {
        self.extensions.update { current in
            var mutable = current
            mutable.append(ext)
            return mutable
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
        number: Double?
    ) -> String {
        String(
            format: "_UAirship.%@ = function() {return %@;};",
            name,
            String(number ?? -1)
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
