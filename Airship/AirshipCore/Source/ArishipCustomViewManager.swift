/* Copyright Airship and Contributors */

import Foundation
public import SwiftUI
public import Combine

/// Type alias for the CustomView builder block
public typealias AirshipCustomViewBuilder = @MainActor @Sendable (AirshipCustomViewArguments)  -> any View

/// Exposes Scene controls to a custom view.
///
/// This class is an `ObservableObject` that can be used to control navigation flow,
/// such as moving forward and backward, and locking the navigation. It is designed
/// to be used with SwiftUI and must be accessed on the main actor.
@MainActor
public class SceneController: ObservableObject {

    /// A Boolean value that indicates whether it is possible to navigate back.
    ///
    /// This property is published and read-only from outside the class. Observers
    /// can use this to update UI elements, such as disabling a "Back" button.
    public var canGoBack: Bool {
        return pagerState?.canGoBack ?? false
    }

    /// A Boolean value that indicates whether it is possible to navigate forward.
    ///
    /// This property is published and read-only from outside the class. Observers
    /// can use this to update UI elements, such as disabling a "Next" button.
    public var canGoForward: Bool {
        return pagerState?.canGoForward ?? false
    }

    /// Dismisses the current scene.
    ///
    /// - Parameter cancelFutureDisplays: A Boolean value that, if `true`,
    ///   should cancel any scheduled or future displays related to this scene.
    public func dismiss(cancelFutureDisplays: Bool = false) {
        environment?.dismiss(cancel: cancelFutureDisplays)
    }

    /// An enumeration representing a navigation request.
    public enum NaviagationRequest {
        /// A request to navigate to the next scene.
        case next
        /// A request to navigate to the previous scene.
        case back
    }

    /// Attempts to navigate based on the specified request.
    ///
    /// - Parameter request: The navigation request, either `.next` or `.back`.
    /// - Returns: A Boolean value indicating whether the navigation was successful.
    public func navigate(request: NaviagationRequest) -> Bool {
        switch(request) {
            case .back:
            return pagerState?.process(request: .back) != nil
        case .next:
            return pagerState?.process(request: .next) != nil
        }
    }

    private let pagerState: PagerState?
    private let environment: ThomasEnvironment?
    init(pagerState: PagerState?, environment: ThomasEnvironment?) {
        self.pagerState = pagerState
        self.environment = environment
    }

    public convenience init() {
        self.init(pagerState: nil, environment: nil)
    }
}

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
