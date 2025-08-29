/* Copyright Airship and Contributors */

#if !os(tvOS) && !os(watchOS)

import Foundation
public import WebKit

/// A standard protocol for handling commands from the NativeBridge..
public protocol JavaScriptCommandDelegate: AnyObject, Sendable {
    /// Delegates must implement this method. Implementations take a model object representing
    /// the JavaScript command which includes the command name, an array of string arguments,
    /// and a dictionary of key-value pairs (all strings).
    ///
    /// If the passed command name is not one the delegate responds to return `NO`. If the command is handled, return
    /// `YES` and the command will not be handled by another delegate.
    ///
    /// To pass information to the delegate from a webview, insert links with a "uairship" scheme,
    /// args in the path and key-value option pairs in the query string. The host
    /// portion of the URL is treated as the command name.
    ///
    /// The basic URL format:
    /// uairship:///command-name/<args>?<key/value options>
    ///
    /// For example, to invoke a command named "foo", and pass in three args (arg1, arg2 and arg3)
    /// and three key-value options {option1:one, option2:two, option3:three}:
    ///
    /// uairship:///foo/arg1/arg2/arg3?option1=one&amp;option2=two&amp;option3=three
    ///
    /// - Parameter command: The javascript command
    /// - Parameter webView: The web view
    /// - Returns: `true` if the command was handled, otherwise `false`
    @MainActor
    func performCommand(_ command: JavaScriptCommand, webView: WKWebView) -> Bool
}

#endif
