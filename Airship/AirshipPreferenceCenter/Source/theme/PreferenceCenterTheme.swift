/* Copyright Airship and Contributors */

import Foundation
import SwiftUI
import UIKit

/// Preferenece Center theme
public struct PreferenceCenterTheme: Equatable {

    /// View controller theme
    public var viewController: PreferenceCenterTheme.ViewController? = nil

    /// Preference center
    public var preferenceCenter: PreferenceCenterTheme.PreferenceCenter? = nil

    /// Common section theme
    public var commonSection: CommonSection? = nil

    /// Labeled section break theme
    public var labeledSectionBreak: LabeledSectionBreak? = nil

    /// Alert theme
    public var alert: Alert? = nil

    /// Channel subscription item theme
    public var channelSubscription: ChannelSubscription? = nil

    /// Contact subscription item theme
    public var contactSubscription: ContactSubscription? = nil

    /// Contact subscription group theme
    public var contactSubscriptionGroup: ContactSubscriptionGroup? = nil

    /// Navigation bar theme
    public struct NavigationBar: Equatable {
        /// The default title
        public var title: String? = nil

        /// Navigation bar background color
        public var backgroundColor: UIColor? = nil
    }

    /// View controller theme
    public struct ViewController: Equatable {
        /// Navigation bar theme
        public var navigationBar: NavigationBar? = nil

        /// Window background color
        public var backgroundColor: UIColor? = nil
    }

    /// Preference center
    public struct PreferenceCenter: Equatable {
        /// Subtitle appearance
        public var subtitleAppearance: TextAppearance? = nil

        /// The retry button background color
        public var retryButtonBackgroundColor: Color? = nil

        /// The retry button label appearance
        public var retryButtonLabelAppearance: TextAppearance? = nil

        /// The retry button label
        public var retryButtonLabel: String? = nil

        /// The retry message
        public var retryMessage: String? = nil

        /// The retry message appearance
        public var retryMessageAppearance: TextAppearance? = nil
    }

    /// Text apperance
    public struct TextAppearance: Equatable {
        /// The text font
        public var font: Font? = nil

        /// The text color
        public var color: Color? = nil
    }

    /// Chip theme for contact subscription groups
    public struct Chip: Equatable {
        /// The check color
        public var checkColor: Color? = nil

        /// Border color around the full chip and check area
        public var borderColor: Color? = nil

        /// Chip label appearance
        public var labelAppearance: TextAppearance? = nil
    }

    /// Common section theme
    public struct CommonSection: Equatable {
        /// Title appearance
        public var titleAppearance: TextAppearance? = nil

        /// Subtitle appearance
        public var subtitleAppearance: TextAppearance? = nil
    }

    /// Labeled section break theme
    public struct LabeledSectionBreak: Equatable {
        /// Title appearance
        public var titleAppearance: TextAppearance? = nil

        /// Background color
        public var backgroundColor: Color? = nil
    }

    /// Alert item theme
    public struct Alert: Equatable {
        /// Title appearance
        public var titleAppearance: TextAppearance? = nil

        /// Subtitle appearance
        public var subtitleAppearance: TextAppearance? = nil

        /// Button label  appearance
        public var buttonLabelAppearance: TextAppearance? = nil

        /// Button background color
        public var buttonBackgroundColor: Color? = nil
    }

    /// Channel subscription item theme
    public struct ChannelSubscription: Equatable {
        /// Title appearance
        public var titleAppearance: TextAppearance? = nil

        /// Subtitle appearance
        public var subtitleAppearance: TextAppearance? = nil

        /// Toggle tint color
        public var toggleTintColor: Color? = nil
    }

    /// Contact subscription item theme
    public struct ContactSubscription: Equatable {
        /// Title appearance
        public var titleAppearance: TextAppearance? = nil

        /// Subtitle appearance
        public var subtitleAppearance: TextAppearance? = nil

        /// Toggle tint color
        public var toggleTintColor: Color? = nil
    }

    /// Contact subscription group item theme
    public struct ContactSubscriptionGroup: Equatable {
        /// Title appearance
        public var titleAppearance: TextAppearance? = nil

        /// Subtitle appearance
        public var subtitleAppearance: TextAppearance? = nil

        /// Chip theme
        public var chip: Chip? = nil
    }
}

struct PreferenceCenterThemeKey: EnvironmentKey {
    static let defaultValue = PreferenceCenterTheme()
}

extension EnvironmentValues {
    /// Airship preference theme environment value
    public var airshipPreferenceCenterTheme: PreferenceCenterTheme {
        get { self[PreferenceCenterThemeKey.self] }
        set { self[PreferenceCenterThemeKey.self] = newValue }
    }
}

extension View {
    /// Overrides the preference center theme
    /// - Parameters:
    ///     - theme: The preference center theme
    public func preferenceCenterTheme(_ theme: PreferenceCenterTheme)
        -> some View
    {
        environment(\.airshipPreferenceCenterTheme, theme)
    }
}

extension PreferenceCenterTheme {
    /// Loads a preference center theme from a plist file
    /// - Parameters:
    ///     - plist: The name of the plist in the bundle
    public static func fromPlist(_ plist: String) throws
        -> PreferenceCenterTheme
    {
        return try PreferenceCenterThemeLoader.fromPlist(plist)
    }
}
