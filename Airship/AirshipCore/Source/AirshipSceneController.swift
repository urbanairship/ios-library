/* Copyright Airship and Contributors */

import Foundation
public import Combine

/// Exposes Scene controls to a custom view.
///
/// This class is an `ObservableObject` that can be used to control navigation flow,
/// such as moving forward and backward, and locking the navigation. It is designed
/// to be used with SwiftUI and must be accessed on the main actor.
@MainActor
public class AirshipSceneController: ObservableObject {

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
    
    private let environment: ThomasEnvironment?
    
    /// Exposes pager state and allows to dispatch navigation requests
    public let pager: PagerController

    init(pagerState: PagerState?, environment: ThomasEnvironment?) {
        self.pager = PagerController(pagerState: pagerState)
        self.environment = environment
    }

    public convenience init() {
        self.init(pagerState: nil, environment: nil)
    }
    
    @MainActor
    public class PagerController: ObservableObject {
        private let pagerState: PagerState?
        
        init(pagerState: PagerState?) {
            self.pagerState = pagerState
        }

        public convenience init() {
            self.init(pagerState: nil)
        }
        
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
        public var canGoNext: Bool {
            return pagerState?.canGoForward ?? false
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
    }
}

