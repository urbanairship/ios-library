/* Copyright Airship and Contributors */

import Combine
import Foundation
public import SwiftUI
import AirshipCore
import AirshipAutomation

/// A SwiftUI view that provides the main content of the Airship debug interface.
///
/// `AirshipDebugContentView` contains the primary debug interface content without
/// navigation wrapper, making it suitable for embedding in existing navigation contexts.
/// It displays the main menu of debug sections that users can navigate to.
///
/// ## Usage
///
/// When embedding in existing navigation, you must handle the navigation destinations
/// using the `navigationDestination` helper from `AirshipDebugRoute`:
///
/// ```swift
/// // Embed in existing navigation with proper destination handling
/// NavigationStack(path: $path) {
///     AirshipDebugContentView()
///         .navigationDestination(for: AirshipDebugRoute.self) { route in
///             route.navigationDestination
///         }
/// }
/// ```
///
/// - Important: When using `AirshipDebugContentView` in a `NavigationStack`, you must
///   add the `.navigationDestination(for: AirshipDebugRoute.self)` modifier to handle
///   navigation to debug sections. Use `route.navigationDestination` to get the
///   appropriate view for each route.
@MainActor
public struct AirshipDebugContentView: View {
    private static let sections = [
        DebugSection(
            icon: "hand.raised.square.fill",
            title: "Privacy Manager",
            route: .privacyManager
        ),
        DebugSection(
            icon: "arrow.left.arrow.right.square.fill",
            title: "Channel",
            route: .channel
        ),
        DebugSection(
            icon: "person.crop.square.fill",
            title: "Contacts",
            route: .contact
        ),
        DebugSection(
            icon: "checkmark.bubble.fill",
            title: "Push",
            route: .push
        ),
        DebugSection(
            icon: "calendar.badge.checkmark",
            title: "Analytics",
            route: .analytics
        ),
        DebugSection(
            icon: "bolt.square.fill",
            title: "In-App Experiences",
            route: .inAppExperience
        ),
        DebugSection(
            icon: "flag.square.fill",
            title: "Feature Flags",
            route: .featureFlags
        ),
        DebugSection(
            icon: "list.bullet.rectangle.fill",
            title: "Preference Centers",
            route: .preferenceCenters
        ),
        DebugSection(
            icon: "iphone.homebutton",
            title: "App Info",
            route: .appInfo
        )
    ]

    public init() {

    }

    @ViewBuilder
    public var body: some View {
        Form {
            ForEach(Self.sections, id: \.self) { item in
                NavigationLink(value: item.route) {
                    HStack {
                        Image(systemName: item.icon)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 24, height: 24)
                            .foregroundColor(.blue)

                        Text(item.title.localized())
                            .foregroundColor(.primary)

                        Spacer()
                    }
                }
            }
        }
    }
}

fileprivate struct DebugSection: Sendable, Hashable {
    let icon: String
    let title: String
    let route: AirshipDebugRoute
}

#Preview {
    AirshipDebugContentView()
}
