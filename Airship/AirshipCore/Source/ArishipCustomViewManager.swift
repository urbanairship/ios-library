/* Copyright Airship and Contributors */


public import SwiftUI

/// Type alias for the CustomView builder block
public typealias AirshipCustomViewBuilder = @MainActor @Sendable (AirshipCustomViewArguments)  -> any View

/// Custom view arguments
public struct AirshipCustomViewArguments: Sendable {
    /// The view's name.
    public var name: String

    /// Optional properties
    public var properties: AirshipJSON?

    /// Sizing info
    public var sizeInfo: SizeInfo

    public struct SizeInfo: Sendable {
        /// If the height is `auto` or not.
        public var isAutoHeight: Bool

        /// If the width is `auto` or not.
        public var isAutoWidth: Bool
    }

}

/// Airship custom view manager for displaying an app view in a Scene based layout.
@MainActor
public final class AirshipCustomViewManager: Sendable {
    /// Shared instance
    public static let shared = AirshipCustomViewManager()
    
    private var builders: [String: AirshipCustomViewBuilder] = [:]

    /// Builder that is used when a view is requested that does not have a registered builder.
    /// The default behavior is to return an empty view.
    public var fallbackBuilder: AirshipCustomViewBuilder = { args in
        return EmptyView()
    }

    /// Registers a custom view builder.
    /// - Parameters:
    ///     - name: The name of the view
    ///     - builder: The builder block
    public func register(name: String, @ViewBuilder builder: @escaping AirshipCustomViewBuilder) {
        self.builders[name] = builder
    }

    /// Unregisters a custom view builder.
    /// - Parameters:
    ///     - name: The name of the view
    public func unregister(name: String) {
        self.builders.removeValue(forKey: name)
    }

    @ViewBuilder
    internal func makeView(args: AirshipCustomViewArguments) -> some View {
        if let block = builders[args.name] {
            AnyView(block(args))
        } else {
            makeFallbackView(args: args)
        }
    }

    private func makeFallbackView(args: AirshipCustomViewArguments) -> some View {
        AirshipLogger.error("Failed to make custom view for name '\(args.name)'")
        return AnyView(fallbackBuilder(args))
    }
}
