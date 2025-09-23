/* Copyright Airship and Contributors */

import Combine
import Foundation
public import SwiftUI

#if canImport(AirshipCore)
import AirshipCore
import AirshipAutomation
#elseif canImport(AirshipKit)
import AirshipKit
#endif

/// A SwiftUI view that provides the main Airship debug interface.
///
/// `AirshipDebugView` presents a comprehensive debug interface for monitoring
/// and debugging various aspects of the Airship SDK. The view uses a navigation
/// stack to organize different debug sections and provides real-time access to
/// push notifications, analytics events, channel data, and other SDK components.
///
/// ## Usage
///
/// ```swift
/// // Basic usage
/// AirshipDebugView()
///
/// // With custom dismissal handling
/// AirshipDebugView {
///     // Handle dismissal
///     print("Debug view dismissed")
/// }
/// ```
///
/// ## Features
///
/// The debug view provides access to:
/// - **Privacy Manager**: Privacy settings and controls
/// - **Channel**: Channel tags, attributes, and subscription lists
/// - **Contacts**: Contact information and channel management
/// - **Push**: Push notification history and details
/// - **Analytics**: Analytics events and associated identifiers
/// - **In-App Experiences**: Automations and experiments
/// - **Feature Flags**: Feature flag details and status
/// - **Preference Centers**: Preference center management
/// - **App Info**: General app and SDK information
///
/// - Note: This view must be used on the main thread.
@MainActor
public struct AirshipDebugView: View {
    private let onDismiss: (@MainActor () -> Void)?

    @State
    private var path: [AirshipDebugRoute] = []

    /// Creates a new AirshipDebugView.
    ///
    /// - Parameter onDismiss: Optional callback that will be called when the
    ///   debug view is dismissed. The callback will be executed on the main thread.
    public init(onDismiss: (@MainActor () -> Void)? = nil) {
        self.onDismiss = onDismiss
    }

    @ViewBuilder
    public var body: some View {
        NavigationStack(path: self.$path) {
            AirshipDebugContentView()
                .toolbar {
                    if let onDismiss {
                        ToolbarItem(placement: .navigationBarLeading) {
                            Button(action: {
                                onDismiss()
                            }) {
                                Image(systemName: "chevron.backward")
                                    .scaleEffect(0.68)
                                    .font(Font.title.weight(.medium))
                            }
                        }
                    }
                }
                .navigationTitle("Airship Debug")
                .navigationDestination(for: AirshipDebugRoute.self) { route in
                    route.navigationDestiation
                }
        }
    }
}

#Preview {
    AirshipDebugView()
}
