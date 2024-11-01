/* Copyright Airship and Contributors */

import Foundation
public import SwiftUI
import UIKit

/// Preference Center theme
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
    public var contactManagement: ContactManagement? = nil

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

        /// Override the preference center config title. If `false`, preference center will display the config title if exists otherwise the default title
        /// Defaults to `true`
        public var overrideConfigTitle: Bool?  = true

        /// Navigation bar background color
        public var backgroundColor: UIColor? = nil

        /// Navigation bar background color for dark mode
        public var backgroundColorDark: UIColor? = nil
        
        /// Navigation bar back button color
        public var backButtonColor: UIColor? = nil

        /// Navigation bar back button color for dark mode
        public var backButtonColorDark: UIColor? = nil

        public init(
            title: String? = nil,
            overrideConfigTitle: Bool? = true,
            backgroundColor: UIColor? = nil,
            backgroundColorDark: UIColor? = nil,
            backButtonColor: UIColor? = nil,
            backButtonColorDark: UIColor? = nil
        ) {
            self.title = title
            self.overrideConfigTitle = overrideConfigTitle
            self.backgroundColor = backgroundColor
            self.backgroundColorDark = backgroundColorDark
            self.backButtonColor = backButtonColor
            self.backButtonColorDark = backButtonColorDark
        }
    }
    /// View controller theme
    public struct ViewController: Equatable, Sendable {
        /// Navigation bar theme
        public var navigationBar: NavigationBar? = nil

        /// Window background color
        public var backgroundColor: UIColor? = nil

        /// Window background color for dark mode
        public var backgroundColorDark: UIColor? = nil

        public init(
            navigationBar: NavigationBar? = nil,
            backgroundColor: UIColor? = nil,
            backgroundColorDark: UIColor? = nil
        ) {
            self.navigationBar = navigationBar
            self.backgroundColor = backgroundColor
            self.backgroundColorDark = backgroundColorDark
        }
    }

    /// Preference center
    public struct PreferenceCenter: Equatable, Sendable {
        /// Subtitle appearance
        public var subtitleAppearance: TextAppearance? = nil

        /// The retry button background color
        public var retryButtonBackgroundColor: Color? = nil

        /// The retry button background color for dark mode
        public var retryButtonBackgroundColorDark: Color? = nil

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
            retryButtonBackgroundColorDark: Color? = nil,
            retryButtonLabelAppearance: TextAppearance? = nil,
            retryButtonLabel: String? = nil,
            retryMessage: String? = nil,
            retryMessageAppearance: TextAppearance? = nil
        ) {
            self.subtitleAppearance = subtitleAppearance
            self.retryButtonBackgroundColor = retryButtonBackgroundColor
            self.retryButtonBackgroundColorDark = retryButtonBackgroundColorDark
            self.retryButtonLabelAppearance = retryButtonLabelAppearance
            self.retryButtonLabel = retryButtonLabel
            self.retryMessage = retryMessage
            self.retryMessageAppearance = retryMessageAppearance
        }
    }

    /// Text appearance
    public struct TextAppearance: Equatable, Sendable {
        /// The text font
        public var font: Font? = nil

        /// The text color
        public var color: Color? = nil

        /// The text color for dark mode
        public var colorDark: Color? = nil

        public init(
            font: Font? = nil,
            color: Color? = nil,
            colorDark: Color? = nil
        ) {
            self.font = font
            self.color = color
            self.colorDark = colorDark
        }
    }

    /// Chip theme for contact subscription groups
    public struct Chip: Equatable, Sendable {
        /// The check color
        public var checkColor: Color? = nil

        /// The check color for dark mode
        public var checkColorDark: Color? = nil

        /// Border color around the full chip and check area
        public var borderColor: Color? = nil

        /// Border color around the full chip and check area for dark mode
        public var borderColorDark: Color? = nil

        /// Chip label appearance
        public var labelAppearance: TextAppearance? = nil

        public init(
            checkColor: Color? = nil,
            checkColorDark: Color? = nil,
            borderColor: Color? = nil,
            borderColorDark: Color? = nil,
            labelAppearance: TextAppearance? = nil
        ) {
            self.checkColor = checkColor
            self.checkColorDark = checkColorDark
            self.borderColor = borderColor
            self.borderColorDark = borderColorDark
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

        /// Background color for dark mode
        public var backgroundColorDark: Color? = nil

        public init(
            titleAppearance: TextAppearance? = nil,
            backgroundColor: Color? = nil,
            backgroundColorDark: Color? = nil
        ) {
            self.titleAppearance = titleAppearance
            self.backgroundColor = backgroundColor
            self.backgroundColorDark = backgroundColorDark
        }
    }

    /// Alert item theme
    public struct Alert: Equatable, Sendable {
        /// Title appearance
        public var titleAppearance: TextAppearance? = nil

        /// Subtitle appearance
        public var subtitleAppearance: TextAppearance? = nil

        /// Button label appearance
        public var buttonLabelAppearance: TextAppearance? = nil

        /// Button background color
        public var buttonBackgroundColor: Color? = nil

        /// Button background color for dark mode
        public var buttonBackgroundColorDark: Color? = nil

        public init(
            titleAppearance: TextAppearance? = nil,
            subtitleAppearance: TextAppearance? = nil,
            buttonLabelAppearance: TextAppearance? = nil,
            buttonBackgroundColor: Color? = nil,
            buttonBackgroundColorDark: Color? = nil
        ) {
            self.titleAppearance = titleAppearance
            self.subtitleAppearance = subtitleAppearance
            self.buttonLabelAppearance = buttonLabelAppearance
            self.buttonBackgroundColor = buttonBackgroundColor
            self.buttonBackgroundColorDark = buttonBackgroundColorDark
        }
    }

    /// Contact management item theme
    public struct ContactManagement: Equatable, Sendable {
        /// Background color
        public var backgroundColor: Color? = nil

        /// Background color for dark mode
        public var backgroundColorDark: Color? = nil

        /// Title appearance
        public var titleAppearance: TextAppearance? = nil

        /// Subtitle appearance
        public var subtitleAppearance: TextAppearance? = nil

        /// List title appearance
        public var listTitleAppearance: TextAppearance? = nil

        /// List subtitle appearance
        public var listSubtitleAppearance: TextAppearance? = nil

        /// Error appearance
        public var errorAppearance: TextAppearance? = nil

        /// Text field placeholder appearance
        public var textFieldTextAppearance: TextAppearance? = nil

        /// Text field placeholder appearance
        public var textFieldPlaceholderAppearance: TextAppearance? = nil

        /// Button label appearance
        public var buttonLabelAppearance: TextAppearance? = nil

        /// Button background color
        public var buttonBackgroundColor: Color? = nil

        /// Button background color for dark mode
        public var buttonBackgroundColorDark: Color? = nil

        /// Destructive button background color - used submit button background color when removing channels
        public var buttonDestructiveBackgroundColor: Color? = nil

        /// Destructive button background color for dark mode
        public var buttonDestructiveBackgroundColorDark: Color? = nil

        public init(
            backgroundColor: Color? = nil,
            backgroundColorDark: Color? = nil,
            titleAppearance: TextAppearance? = nil,
            subtitleAppearance: TextAppearance? = nil,
            listTitleAppearance: TextAppearance? = nil,
            listSubtitleAppearance: TextAppearance? = nil,
            errorAppearance: TextAppearance? = nil,
            textFieldTextAppearance: TextAppearance? = nil,
            textFieldPlaceholderAppearance: TextAppearance? = nil,
            buttonLabelAppearance: TextAppearance? = nil,
            buttonBackgroundColor: Color? = nil,
            buttonBackgroundColorDark: Color? = nil,
            buttonDestructiveBackgroundColor: Color? = nil,
            buttonDestructiveBackgroundColorDark: Color? = nil
        ) {
            self.backgroundColor = backgroundColor
            self.backgroundColorDark = backgroundColorDark
            self.titleAppearance = titleAppearance
            self.subtitleAppearance = subtitleAppearance
            self.listTitleAppearance = listTitleAppearance
            self.listSubtitleAppearance = listSubtitleAppearance
            self.errorAppearance = errorAppearance
            self.textFieldTextAppearance = textFieldTextAppearance
            self.textFieldPlaceholderAppearance = textFieldPlaceholderAppearance
            self.buttonLabelAppearance = buttonLabelAppearance
            self.buttonBackgroundColor = buttonBackgroundColor
            self.buttonBackgroundColorDark = buttonBackgroundColorDark
            self.buttonDestructiveBackgroundColor = buttonDestructiveBackgroundColor
            self.buttonDestructiveBackgroundColorDark = buttonDestructiveBackgroundColorDark
        }
    }

    /// Channel subscription item theme
    public struct ChannelSubscription: Equatable, Sendable {
        /// Title appearance
        public var titleAppearance: TextAppearance? = nil

        /// Subtitle appearance
        public var subtitleAppearance: TextAppearance? = nil

        /// Empty appearance - for when a section has an empty message set
        public var emptyTextAppearance: TextAppearance? = nil

        /// Toggle tint color
        public var toggleTintColor: Color? = nil

        /// Toggle tint color for dark mode
        public var toggleTintColorDark: Color? = nil

        public init(
            titleAppearance: TextAppearance? = nil,
            subtitleAppearance: TextAppearance? = nil,
            emptyTextAppearance: TextAppearance? = nil,
            toggleTintColor: Color? = nil,
            toggleTintColorDark: Color? = nil
        ) {
            self.titleAppearance = titleAppearance
            self.subtitleAppearance = subtitleAppearance
            self.emptyTextAppearance = emptyTextAppearance
            self.toggleTintColor = toggleTintColor
            self.toggleTintColorDark = toggleTintColorDark
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

        /// Toggle tint color for dark mode
        public var toggleTintColorDark: Color? = nil

        public init(
            titleAppearance: TextAppearance? = nil,
            subtitleAppearance: TextAppearance? = nil,
            toggleTintColor: Color? = nil,
            toggleTintColorDark: Color? = nil
        ) {
            self.titleAppearance = titleAppearance
            self.subtitleAppearance = subtitleAppearance
            self.toggleTintColor = toggleTintColor
            self.toggleTintColorDark = toggleTintColorDark
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
    public func preferenceCenterTheme(
        _ theme: PreferenceCenterTheme
    )-> some View {
        environment(\.airshipPreferenceCenterTheme, theme)
    }
}

extension PreferenceCenterTheme {
    /// Loads a preference center theme from a plist file
    /// - Parameters:
    ///     - plist: The name of the plist in the bundle
    public static func fromPlist(
        _ plist: String
    ) throws -> PreferenceCenterTheme {
        return try PreferenceCenterThemeLoader.fromPlist(plist)
    }
}

extension ProgressView {
    @ViewBuilder
    func airshipSetTint(color: Color) -> some View {
        if #available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *) {
            self.tint(color)
        } else {
            self.accentColor(color)
        }
    }
}

extension Color {
    
    /// Inverts the color - used for inverted primary and secondary colors on LabeledButtons
    func inverted() -> Color {
        let uiColor = UIColor(self)
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        let invertedColor = Color(
            red: Double(1 - red),
            green: Double(1 - green),
            blue: Double(1 - blue),
            opacity: Double(alpha)
        )
        return invertedColor
    }

    /**
     ** Derives secondary variant for a particular color by shifting a given color's RGBA values
     ** by the difference between the current primary and secondary colors
     **/
    func secondaryVariant(for colorScheme: ColorScheme) -> Color {
        /// Convert target color to UIColor
        let targetUIColor = UIColor(self)

        /// Convert primary and secondary colors to UIColor
        let primaryUIColor = UIColor(.primary)
        let secondaryUIColor = UIColor(.secondary)

        /// Calculate RGBA differences between primary and secondary
        var primaryRed: CGFloat = 0, primaryGreen: CGFloat = 0, primaryBlue: CGFloat = 0, primaryAlpha: CGFloat = 0
        primaryUIColor.getRed(&primaryRed, green: &primaryGreen, blue: &primaryBlue, alpha: &primaryAlpha)

        var secondaryRed: CGFloat = 0, secondaryGreen: CGFloat = 0, secondaryBlue: CGFloat = 0, secondaryAlpha: CGFloat = 0
        secondaryUIColor.getRed(&secondaryRed, green: &secondaryGreen, blue: &secondaryBlue, alpha: &secondaryAlpha)

        let redDiff = secondaryRed - primaryRed
        let greenDiff = secondaryGreen - primaryGreen
        let blueDiff = secondaryBlue - primaryBlue
        let alphaDiff = secondaryAlpha - primaryAlpha

        /// Apply the differences to the target color
        var targetRed: CGFloat = 0, targetGreen: CGFloat = 0, targetBlue: CGFloat = 0, targetAlpha: CGFloat = 0
        if targetUIColor.getRed(&targetRed, green: &targetGreen, blue: &targetBlue, alpha: &targetAlpha) {
            let newRed = colorScheme == .light ? max(targetRed - redDiff, 0) : min(targetRed + redDiff, 1)
            let newGreen = colorScheme == .light ? max(targetGreen - greenDiff, 0) : min(targetGreen + greenDiff, 1)
            let newBlue = colorScheme == .light ? max(targetBlue - blueDiff, 0) : min(targetBlue + blueDiff, 1)
            let newAlpha = targetAlpha + alphaDiff

            return Color(UIColor(red: newRed, green: newGreen, blue: newBlue, alpha: newAlpha))
        } else {
            return self /// Return the original color if unable to modify
        }
    }
}
