/* Copyright Airship and Contributors */

import Foundation

#if canImport(UIKit)
import UIKit
#endif

/// Delegate protocol for accepting and rejecting URLs.
public protocol URLAllowListDelegate: Sendable {
    /**
     * Called when a URL has been allowed by the SDK, but before the URL is fetched.
     *
     * - Parameters:
     *   - url: The URL allowed by the SDK.
     *   - scope: The scope of the desired match.
     *
     * - Returns: `true` to accept this URL, `false`  to reject this URL.
     */
    func allowURL(_ url: URL, scope: URLAllowListScope) -> Bool
}


/// Class for accepting and verifying webview URLs.
///
/// URL allow list entries are written as URL patterns with optional wildcard matching:
///
/// ~~~
/// <scheme> := <any char combination, '*' are treated as wildcards>
///
/// <host> := '*' | '*.'<any char combination except '/' and '*'> | <any char combination except '/' and '*'>
///
/// <path> := <any char combination, '*' are treated as wildcards>
///
/// <pattern> := '*' | <scheme>://<host>/<path> | <scheme>://<host> | <scheme>:/<path> | <scheme>:///<path>
/// ~~~
///
/// A single wildcard will match any URI.
/// Wildcards in the scheme pattern will match any characters, and a single wildcard in the scheme will match any scheme.
/// The wildcard in a host pattern `"*.mydomain.com"` will match anything within the mydomain.com domain.
/// Wildcards in the path pattern will match any characters, including subdirectories.
///
/// Note that NSURL does not support internationalized domains containing non-ASCII characters.
/// All URL allow list entries for internationalized domains must be in ASCII IDNA format as
/// specified in https://tools.ietf.org/html/rfc3490
public protocol AirshipURLAllowList: Sendable {

    /// The URL allow list delegate.
    ///
    /// - note: The delegate is not retained.
    @MainActor
    var delegate: (any URLAllowListDelegate)? { get set }

    /// If set, this block will be called when a URL is checked to override if it should be allowed or not.
    /// This will be called in place of the `URLAllowListDelegate` delegate.
    @MainActor
    var onAllowURL: (@MainActor @Sendable (URL, URLAllowListScope) -> Bool)? { get set }

    /// Determines whether a given URL is allowed, with the implicit scope `URLAllowListScope.all`.
    ///
    /// - Parameters:
    ///   - url: The URL under consideration.
    ///
    /// - Returns: `true` if the URL is allowed, `false` otherwise.
    @MainActor
    func isAllowed(_ url: URL?) -> Bool

    /// Determines whether a given URL is allowed.
    ///
    /// - Parameters:
    ///   - url: The URL under consideration.
    ///   - scope: The scope of the desired match.
    ///
    /// - Returns: `true` if the URL is allowed, `false` otherwise.
    @MainActor
    func isAllowed(_ url: URL?, scope: URLAllowListScope) -> Bool

    /// Add an entry to the URL allow list.
    ///
    /// - Parameters:
    ///   - patternString: A URL allow list pattern string.
    ///   - scope: The scope of the pattern.
    ///
    /// - Returns: `true` if the URL allow list pattern was validated and added, `false` otherwise.
    @discardableResult
    @MainActor
    func addEntry(_ patternString: String, scope: URLAllowListScope) -> Bool

    /// Add an entry to the URL allow list, with the implicit scope `URLAllowListScope.all`.
    ///
    /// - Parameter patternString: A URL allow list pattern string.
    ///
    /// - Returns: `true` if the URL allow list pattern was validated and added, `false` otherwise.
    @discardableResult
    @MainActor
    func addEntry(_ patternString: String) -> Bool
}

@MainActor
final class DefaultAirshipURLAllowList: AirshipURLAllowList {
    /// `<scheme> := <any chars (no spaces), '*' will match 0 or more characters>`
    private static let schemeRegex: String = "^([^\\s]*)$"

    /// `<host> := '*' | *.<valid host characters> | <valid host characters>`
    private static let hostRegex: String = "^((\\*)|(\\*\\.[^/\\*]+)|([^/\\*]+))$"

    /// `<path> | <scheme> := <any chars (no spaces), '*' will match 0 or more characters>`
    private static let pathRegex: String = "^([^\\s]*)$"

    /// Regular expression to escape from a pattern
    private static let escapeRegexCharacters: [String] = [
        "\\", ".", "[", "]", "{", "}", "(", ")", "^", "$", "?", "+", "|", "*",
    ]

    private let schemePatternValidator: NSRegularExpression = try! NSRegularExpression(
        pattern: schemeRegex,
        options: .useUnicodeWordBoundaries
    )
    private let hostPatternValidator: NSRegularExpression = try! NSRegularExpression(
        pattern: hostRegex,
        options: .useUnicodeWordBoundaries
    )
    private let pathPatternValidator: NSRegularExpression = try! NSRegularExpression(
        pattern: pathRegex,
        options: .useUnicodeWordBoundaries
    )

    @MainActor
    private var entries: Set<AllowListEntry> = []

    init(airshipConfig: AirshipConfig) {
        addEntry("https://*.urbanairship.com")
        addEntry("https://*.asnapieu.com")

        if let initialConfigURL = airshipConfig.initialConfigURL {
            addEntry(initialConfigURL)
        }

        // Open only
        addEntry("mailto:", scope: .openURL)
        addEntry("sms:", scope: .openURL)
        addEntry("tel:", scope: .openURL)

        if (airshipConfig.urlAllowList == nil && airshipConfig.urlAllowListScopeOpenURL == nil) {
            addEntry("*", scope: .openURL)
        }

        #if !os(watchOS)
        addEntry(
            UIApplication.openSettingsURLString,
            scope: .openURL
        )
        #endif

        airshipConfig.urlAllowList?.forEach {
            addEntry($0)
        }

        airshipConfig.urlAllowListScopeOpenURL?.forEach {
            addEntry($0, scope: .openURL)
        }

        airshipConfig.urlAllowListScopeJavaScriptInterface?.forEach {
            addEntry($0, scope: .javaScriptInterface)
        }
    }

    init() {
    }


    @MainActor
    var delegate: (any URLAllowListDelegate)? = nil

    @MainActor
    var onAllowURL: (@MainActor @Sendable (URL, URLAllowListScope) -> Bool)? = nil

    @discardableResult
    @MainActor
    func addEntry(_ patternString: String) -> Bool {
        return addEntry(patternString, scope: .all)
    }

    @discardableResult
    @MainActor
    func addEntry(
        _ patternString: String,
        scope: URLAllowListScope
    ) -> Bool {
        if patternString.isEmpty {
            AirshipLogger.error(
                "Invalid URL allow list pattern: \(patternString)"
            )
            return false
        }

        let escapedPattern = Self.escapeSchemeWildcard(patternString)

        if patternString == "*" {
            let entry = AllowListEntry.entryWithMatcher(
                matcherForScheme("", host: "", path: ""),
                scope: scope,
                pattern: patternString
            )
            entries.insert(entry)
            return true
        }

        guard let url = URL(string: escapedPattern) else {
            AirshipLogger.error(
                "Unable to parse URL for pattern: \(patternString)"
            )
            return false
        }

        // Scheme WILDCARD -> *
        let scheme =
            url.scheme?.replacingOccurrences(of: "WILDCARD", with: "*") ?? ""
        if scheme.isEmpty
            || !Self.validatePattern(
                scheme,
                expression: schemePatternValidator
            )
        {
            AirshipLogger.error(
                "Invalid scheme '\(scheme)' in URL allow list pattern: \(patternString)"
            )
            return false
        }

        let host = url.host ?? ""
        if !host.isEmpty
            && !Self.validatePattern(
                host,
                expression: hostPatternValidator
            )
        {
            AirshipLogger.error(
                "Invalid host '\(host)' in URL allow list pattern: \(patternString)"
            )
            return false
        }

        let path = Self.pathForUrl(url) ?? ""
        if !path.isEmpty
            && !Self.validatePattern(
                path,
                expression: pathPatternValidator
            )
        {
            AirshipLogger.error(
                "Invalid path '\(path)' in URL allow list pattern: \(patternString)"
            )
            return false
        }

        let entry = AllowListEntry.entryWithMatcher(
            matcherForScheme(scheme, host: host, path: path),
            scope: scope,
            pattern: patternString
        )
        entries.insert(entry)

        return true
    }

    @MainActor
    func isAllowed(_ url: URL?) -> Bool {
        return isAllowed(url, scope: .all)
    }

    @MainActor
    func isAllowed(_ url: URL?, scope: URLAllowListScope) -> Bool {
        guard let url = url else {
            return false
        }

        var match = false

        var matchedScope: URLAllowListScope = []

        for entry in entries {
            if entry.matcher(url) {
                matchedScope.formUnion(entry.scope)
            }
        }

        match = matchedScope.contains(scope)

        // If the url is allowed, allow the delegate or block to reject the url
        if match {
            match = if let onAllowURL {
                onAllowURL(url, scope)
            } else if let delegate {
                delegate.allowURL(url, scope: scope)
            } else {
                match
            }
        }

        return match
    }

    // MARK: - Internal types / helpers

    /// Escapes URL allow list pattern strings so that they don't contain unanticipated regex characters.
    private static func escapeRegexString(
        _ input: String,
        escapingWildcards: Bool
    ) -> String {
        var input = input

        // Prefix all special characters with a backslash
        for char in escapeRegexCharacters {
            input = input.replacingOccurrences(
                of: char,
                with: "\\".appending(char)
            )
        }

        // If wildcards are intended, transform them in to the appropriate regex pattern.
        if !escapingWildcards {
            input = input.replacingOccurrences(of: "\\*", with: ".*")
        }

        return input
    }

    private static func validatePattern(
        _ pattern: String,
        expression: NSRegularExpression
    ) -> Bool {
        let matches = expression.numberOfMatches(
            in: pattern,
            options: [],
            range: NSMakeRange(0, pattern.count)
        )

        return matches > 0
    }

    private static func escapeSchemeWildcard(_ pattern: String) -> String {
        var components = pattern.components(separatedBy: ":")
        guard components.count > 1 else {
            return pattern
        }
        let schemeComponent = components.removeFirst()
            .replacingOccurrences(
                of: "*",
                with: "WILDCARD"
            )
        var array = [schemeComponent]
        array.append(contentsOf: components)

        return array.joined(separator: ":")
    }

    private static func compilePattern(_ pattern: String)
        -> NSRegularExpression?
    {
        var pattern = pattern
        if !pattern.hasPrefix("^") {
            pattern = "^".appending(pattern)
        }
        if !pattern.hasSuffix("$") {
            pattern = pattern.appending("$")
        }

        return try? NSRegularExpression(pattern: pattern, options: [])
    }

    private static func pathForUrl(_ url: URL) -> String? {
        // URL path using CoreFoundation, which preserves trailing slashes
        guard let path = CFURLCopyPath(url as CFURL) as String? else {
            // If the path is nil then it's nonstandard, use the resource specifier as path
            return (url as NSURL).resourceSpecifier
        }

        return path
    }

    private func matcherForScheme(_ scheme: String, host: String, path: String)
        -> AllowListMatcher
    {
        let schemeRegex: NSRegularExpression?
        if scheme.isEmpty || scheme == "*" {
            schemeRegex = nil
        } else {
            schemeRegex = Self.compilePattern(
                Self.escapeRegexString(scheme, escapingWildcards: false)
            )
        }

        let hostRegex: NSRegularExpression?
        if host.isEmpty || host == "*" {
            hostRegex = nil
        } else if host.hasPrefix("*.") {
            let substring = host[host.index(host.startIndex, offsetBy: 2)...]
            hostRegex = Self.compilePattern(
                "(.*\\.)?"
                    .appending(
                        Self.escapeRegexString(
                            String(substring),
                            escapingWildcards: true
                        )
                    )
            )
        } else {
            hostRegex = Self.compilePattern(
                "(.*\\.)?"
                    .appending(
                        Self.escapeRegexString(
                            host,
                            escapingWildcards: true
                        )
                    )
            )
        }

        let pathRegex: NSRegularExpression?
        if path.isEmpty || path == "/*" || path == "*" {
            pathRegex = nil
        } else {
            pathRegex = Self.compilePattern(
                Self.escapeRegexString(path, escapingWildcards: false)
            )
        }

        return { @MainActor (url: URL) -> Bool in
            let scheme = url.scheme ?? ""
            if let expression = schemeRegex,
                scheme.isEmpty
                    || !Self.validatePattern(
                        scheme,
                        expression: expression
                    )
            {
                return false
            }

            let host = url.host ?? ""
            if let expression = hostRegex,
                host.isEmpty
                    || !Self.validatePattern(
                        host,
                        expression: expression
                    )
            {
                return false
            }

            let path = Self.pathForUrl(url) ?? ""
            if let expression = pathRegex,
                path.isEmpty
                    || !Self.validatePattern(
                        path,
                        expression: expression
                    )
            {
                return false
            }

            return true
        }
    }

    /// Block mapping URLs to allow list status.
    private typealias AllowListMatcher = @MainActor @Sendable (URL) -> Bool

    private struct AllowListEntry: Hashable, Sendable {
        let matcher: AllowListMatcher
        let scope: URLAllowListScope

        // Pattern is only used for hashing
        private let pattern: String

        static func entryWithMatcher(
            _ matcher: @escaping AllowListMatcher,
            scope: URLAllowListScope,
            pattern: String
        ) -> AllowListEntry {
            return AllowListEntry(
                matcher: matcher,
                scope: scope,
                pattern: pattern
            )
        }

        static func == (
            lhs: DefaultAirshipURLAllowList.AllowListEntry,
            rhs: DefaultAirshipURLAllowList.AllowListEntry
        ) -> Bool {
            lhs.scope == rhs.scope && lhs.pattern == rhs.pattern
        }

        func hash(into hasher: inout Hasher) {
            hasher.combine(scope.rawValue)
            hasher.combine(pattern)
        }
    }
}

// Scope options for URL allow list matching
public struct URLAllowListScope: OptionSet, Sendable, Equatable {
    public let rawValue: Int

    // Scope that is checked before loading the JavaScript Native Bridge into
    // a WebView when using the `NativeBridge`
    public static let javaScriptInterface: URLAllowListScope = URLAllowListScope(rawValue: 1 << 0)

    // Scope that is checked before opening a URL.
    public static let openURL: URLAllowListScope = URLAllowListScope(rawValue: 1 << 1)

    // All scopes
    public static let all: URLAllowListScope = [.javaScriptInterface, .openURL]

    public init(rawValue: Int) {
        self.rawValue = rawValue
    }
}
