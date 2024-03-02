/* Copyright Airship and Contributors */

import Foundation
import SwiftUI
import UIKit

/// Preferenece Center theme
public struct PreferenceCenterTheme: Equatable, Sendable {

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
    
    /// Contact management theme
    public var  contactManagement: ContactManagement? = nil

    /// Channel subscription item theme
    public var channelSubscription: ChannelSubscription? = nil

    /// Contact subscription item theme
    public var contactSubscription: ContactSubscription? = nil

    /// Contact subscription group theme
    public var contactSubscriptionGroup: ContactSubscriptionGroup? = nil

    /// Navigation bar theme
    public struct NavigationBar: Equatable, Sendable {
        /// The default title
        public var title: String? = nil

        /// Override the preference center config title. If `false`, preference center will dispaly the config title if exists otherwise the default title
        /// Defaults to `true`
        public var overrideConfigTitle: Bool?  = true
        
        /// Navigation bar background color
        public var backgroundColor: UIColor? = nil
        
        public init(
            title: String? = nil,
            overrideConfigTitle: Bool? = true,
            backgroundColor: UIColor? = nil
        ) {
            self.title = title
            self.overrideConfigTitle = overrideConfigTitle
            self.backgroundColor = backgroundColor
        }
    }

    /// View controller theme
    public struct ViewController: Equatable, Sendable {
        /// Navigation bar theme
        public var navigationBar: NavigationBar? = nil

        /// Window background color
        public var backgroundColor: UIColor? = nil

        public init(
            navigationBar: NavigationBar? = nil,
            backgroundColor: UIColor? = nil
        ) {
            self.navigationBar = navigationBar
            self.backgroundColor = backgroundColor
        }
    }

    /// Preference center
    public struct PreferenceCenter: Equatable, Sendable {
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

        public init(
            subtitleAppearance: TextAppearance? = nil,
            retryButtonBackgroundColor: Color? = nil,
            retryButtonLabelAppearance: TextAppearance? = nil,
            retryButtonLabel: String? = nil, 
            retryMessage: String? = nil,
            retryMessageAppearance: TextAppearance? = nil
        ) {
            self.subtitleAppearance = subtitleAppearance
            self.retryButtonBackgroundColor = retryButtonBackgroundColor
            self.retryButtonLabelAppearance = retryButtonLabelAppearance
            self.retryButtonLabel = retryButtonLabel
            self.retryMessage = retryMessage
            self.retryMessageAppearance = retryMessageAppearance
        }
    }

    /// Text apperance
    public struct TextAppearance: Equatable, Sendable {
        /// The text font
        public var font: Font? = nil

        /// The text color
        public var color: Color? = nil

        public init(
            font: Font? = nil,
            color: Color? = nil
        ) {
            self.font = font
            self.color = color
        }
    }

    /// Chip theme for contact subscription groups
    public struct Chip: Equatable, Sendable {
        /// The check color
        public var checkColor: Color? = nil

        /// Border color around the full chip and check area
        public var borderColor: Color? = nil

        /// Chip label appearance
        public var labelAppearance: TextAppearance? = nil

        public init(
            checkColor: Color? = nil,
            borderColor: Color? = nil,
            labelAppearance: TextAppearance? = nil
        ) {
            self.checkColor = checkColor
            self.borderColor = borderColor
            self.labelAppearance = labelAppearance
        }
    }

    /// Common section theme
    public struct CommonSection: Equatable, Sendable {
        /// Title appearance
        public var titleAppearance: TextAppearance? = nil

        /// Subtitle appearance
        public var subtitleAppearance: TextAppearance? = nil

        public init(
            titleAppearance: TextAppearance? = nil,
            subtitleAppearance: TextAppearance? = nil
        ) {
            self.titleAppearance = titleAppearance
            self.subtitleAppearance = subtitleAppearance
        }
    }

    /// Labeled section break theme
    public struct LabeledSectionBreak: Equatable, Sendable {
        /// Title appearance
        public var titleAppearance: TextAppearance? = nil

        /// Background color
        public var backgroundColor: Color? = nil

        public init(
            titleAppearance: TextAppearance? = nil, 
            backgroundColor: Color? = nil
        ) {
            self.titleAppearance = titleAppearance
            self.backgroundColor = backgroundColor
        }
    }

    /// Alert item theme
    public struct Alert: Equatable, Sendable {
        /// Title appearance
        public var titleAppearance: TextAppearance? = nil

        /// Subtitle appearance
        public var subtitleAppearance: TextAppearance? = nil

        /// Button label  appearance
        public var buttonLabelAppearance: TextAppearance? = nil

        /// Button background color
        public var buttonBackgroundColor: Color? = nil

        public init(
            titleAppearance: TextAppearance? = nil,
            subtitleAppearance: TextAppearance? = nil,
            buttonLabelAppearance: TextAppearance? = nil,
            buttonBackgroundColor: Color? = nil
        ) {
            self.titleAppearance = titleAppearance
            self.subtitleAppearance = subtitleAppearance
            self.buttonLabelAppearance = buttonLabelAppearance
            self.buttonBackgroundColor = buttonBackgroundColor
        }
    }
    
    /// Contact management item theme
    public struct ContactManagement: Equatable, Sendable {
        
        /// Background color
        public var backgroundColor: Color? = nil
        
        /// Title appearance
        public var titleAppearance: TextAppearance? = nil

        /// Subtitle appearance
        public var subtitleAppearance: TextAppearance? = nil

        /// Error appearance
        public var errorAppearance: TextAppearance? = nil
        
        /// Button label  appearance
        public var buttonLabelAppearance: TextAppearance? = nil

        /// Button background color
        public var buttonBackgroundColor: Color? = nil

        public init(
            backgroundColor: Color? = nil,
            titleAppearance: TextAppearance? = nil,
            subtitleAppearance: TextAppearance? = nil,
            errorAppearance: TextAppearance? = nil,
            buttonLabelAppearance: TextAppearance? = nil,
            buttonBackgroundColor: Color? = nil
        ) {
            self.titleAppearance = titleAppearance
            self.subtitleAppearance = subtitleAppearance
            self.errorAppearance = errorAppearance
            self.buttonLabelAppearance = buttonLabelAppearance
            self.buttonBackgroundColor = buttonBackgroundColor
        }
    }
    
    /// Channel subscription item theme
    public struct ChannelSubscription: Equatable, Sendable {
        /// Title appearance
        public var titleAppearance: TextAppearance? = nil

        /// Subtitle appearance
        public var subtitleAppearance: TextAppearance? = nil

        /// Toggle tint color
        public var toggleTintColor: Color? = nil

        public init(
            titleAppearance: TextAppearance? = nil,
            subtitleAppearance: TextAppearance? = nil,
            toggleTintColor: Color? = nil
        ) {
            self.titleAppearance = titleAppearance
            self.subtitleAppearance = subtitleAppearance
            self.toggleTintColor = toggleTintColor
        }
    }

    /// Contact subscription item theme
    public struct ContactSubscription: Equatable, Sendable {
        /// Title appearance
        public var titleAppearance: TextAppearance? = nil

        /// Subtitle appearance
        public var subtitleAppearance: TextAppearance? = nil

        /// Toggle tint color
        public var toggleTintColor: Color? = nil

        public init(
            titleAppearance: TextAppearance? = nil,
            subtitleAppearance: TextAppearance? = nil,
            toggleTintColor: Color? = nil
        ) {
            self.titleAppearance = titleAppearance
            self.subtitleAppearance = subtitleAppearance
            self.toggleTintColor = toggleTintColor
        }
    }

    /// Contact subscription group item theme
    public struct ContactSubscriptionGroup: Equatable, Sendable {
        /// Title appearance
        public var titleAppearance: TextAppearance? = nil

        /// Subtitle appearance
        public var subtitleAppearance: TextAppearance? = nil

        /// Chip theme
        public var chip: Chip? = nil

        public init(
            titleAppearance: TextAppearance? = nil,
            subtitleAppearance: TextAppearance? = nil,
            chip: Chip? = nil
        ) {
            self.titleAppearance = titleAppearance
            self.subtitleAppearance = subtitleAppearance
            self.chip = chip
        }
    }
    
    public init(
        viewController: PreferenceCenterTheme.ViewController? = nil,
        preferenceCenter: PreferenceCenterTheme.PreferenceCenter? = nil,
        commonSection: CommonSection? = nil,
        labeledSectionBreak: LabeledSectionBreak? = nil,
        alert: Alert? = nil,
        contactManagement: ContactManagement? = nil,
        channelSubscription: ChannelSubscription? = nil,
        contactSubscription: ContactSubscription? = nil,
        contactSubscriptionGroup: ContactSubscriptionGroup? = nil
    ) {
        self.viewController = viewController
        self.preferenceCenter = preferenceCenter
        self.commonSection = commonSection
        self.labeledSectionBreak = labeledSectionBreak
        self.alert = alert
        self.contactManagement = contactManagement
        self.channelSubscription = channelSubscription
        self.contactSubscription = contactSubscription
        self.contactSubscriptionGroup = contactSubscriptionGroup
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
