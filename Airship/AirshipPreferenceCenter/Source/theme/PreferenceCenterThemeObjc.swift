/* Copyright Airship and Contributors */

import Foundation
import UIKit
import SwiftUI

/// Preference center theme
@objc(UAPreferenceCenterTheme)
public class _PreferenceCenterThemeObjc: NSObject {
    /// View controller theme
    @objc public var viewController: ViewController? = nil

    /// Preference Center theme
    @objc public var preferenceCenter: PreferenceCenter? = nil

    /// Common section theme
    @objc public var commonSection: CommonSection? = nil

    /// Labeled section break theme
    @objc public var labeledSectionBreak: LabeledSectionBreak? = nil

    /// Alert theme
    @objc public var alert: Alert? = nil

    /// Channel subscription item theme
    @objc public var channelSubscription: ChannelSubscription? = nil

    /// Contact subscription item theme
    @objc public var contactSubscription: ContactSubscription? = nil

    /// Contact subscription group theme
    @objc public var contactSubscriptionGroup: ContactSubscriptionGroup? = nil

    /// Navigation bar theme
    @objc(UAPreferenceCenterThemeNavigationBar)
    public class NavigationBar: NSObject {
        /// The default title
        @objc public var title: String? = nil

        /// Navigation bar title font
        @objc public var titleFont: UIFont? = nil

        /// Navigation bar title color
        @objc public var titleColor: UIColor? = nil

        /// Navigation bar tint color
        @objc public var tintColor: UIColor? = nil

        /// Navigation bar background color
        @objc public var backgroundColor: UIColor? = nil
    }

    /// View controller theme
    @objc(UAPreferenceCenterThemeViewController)
    public class ViewController: NSObject {
        /// Navigation bar theme
        @objc public var navigationBar: NavigationBar? = nil

        /// Window background color
        @objc public var backgroundColor: UIColor? = nil
    }

    /// Text apperance
    @objc(UAPreferenceCenterThemeTextAppearance)
    public class TextAppearance: NSObject {

        /// The text font
        @objc public var font: UIFont? = nil

        /// The text color
        @objc public var color: UIColor? = nil
    }

    /// Preferenece Center theme
    @objc(UAPreferenceCenterThemePreferenceCenter)
    public class PreferenceCenter: NSObject {
        /// Subtitle appearance
        @objc public var subtitleAppearance: TextAppearance? = nil

        /// The retry button background color
        @objc public var retryButtonBackgroundColor: UIColor? = nil

        /// The retry button label appearance
        @objc public var retryButtonLabelAppearance: TextAppearance? = nil

        /// The retry button label
        @objc public var retryButtonLabel: String? = nil

        /// The retry message
        @objc public var retryMessage: String? = nil

        /// The retry message appearance
        @objc public var retryMessageAppearance: TextAppearance? = nil
    }

    /// Chip theme for contact subscription groups
    @objc(UAPreferenceCenterThemeChip)
    public class Chip: NSObject {
        /// The check color
        @objc public var checkColor: UIColor? = nil

        /// Border color around the full chip and check area
        @objc public var borderColor: UIColor? = nil

        /// Chip label appearance
        @objc public var labelAppearance: TextAppearance? = nil
    }

    /// Common section theme
    @objc(UAPreferenceCenterThemeCommonSection)
    public class CommonSection: NSObject {
        /// Title appearance
        @objc public var titleAppearance: TextAppearance? = nil

        /// Subtitle appearance
        @objc public var subtitleAppearance: TextAppearance? = nil
    }

    /// Labeled section break theme
    @objc(UAPreferenceCenterThemeLabeledSectionBreak)
    public class LabeledSectionBreak: NSObject {
        /// Title appearance
        @objc public var titleAppearance: TextAppearance? = nil

        /// Background color
        @objc public var backgroundColor: UIColor? = nil
    }

    /// Alert item theme
    @objc(UAPreferenceCenterThemeAlert)
    public class Alert: NSObject {
        /// Title appearance
        @objc public var titleAppearance: TextAppearance? = nil

        /// Subtitle appearance
        @objc public var subtitleAppearance: TextAppearance? = nil

        /// Button label  appearance
        @objc public var buttonLabelAppearance: TextAppearance? = nil

        /// Button background color
        @objc public var buttonBackgroundColor: UIColor? = nil
    }

    /// Channel subcription item theme
    @objc(UAPreferenceCenterThemeChannelSubscription)
    public class ChannelSubscription: NSObject {
        /// Title appearance
        @objc public var titleAppearance: TextAppearance? = nil

        /// Subtitle appearance
        @objc public var subtitleAppearance: TextAppearance? = nil

        /// Toggle tint color
        @objc public var toggleTintColor: UIColor? = nil
    }

    /// Contact subscription item theme
    @objc(UAPreferenceCenterThemeContactSubscription)
    public class ContactSubscription: NSObject {
        /// Title appearance
        @objc public var titleAppearance: TextAppearance? = nil

        /// Subtitle appearance
        @objc public var subtitleAppearance: TextAppearance? = nil

        /// Toggle tint color
        @objc public var toggleTintColor: UIColor? = nil
    }

    /// Contact subscription group item theme
    @objc(UAPreferenceCenterThemeContactSubscriptionGroup)
    public class ContactSubscriptionGroup: NSObject {
        /// Title appearance
        @objc public var titleAppearance: TextAppearance? = nil

        /// Subtitle appearance
        @objc public var subtitleAppearance: TextAppearance? = nil

        /// Chip theme
        @objc public var chip: Chip? = nil
    }
}

fileprivate extension UIFont {
    func toFont() -> Font {
        return Font(self)
    }
}

fileprivate extension UIColor {
    func toColor() -> Color {
        return Color(self)
    }
}

fileprivate extension _PreferenceCenterThemeObjc.TextAppearance {
    func toTextApperance() -> PreferenceCenterTheme.TextAppearance {
        return PreferenceCenterTheme.TextAppearance(
            font: self.font?.toFont(),
            color: self.color?.toColor()
        )
    }
}

fileprivate extension _PreferenceCenterThemeObjc.Chip {
    func toChip() -> PreferenceCenterTheme.Chip {
        return PreferenceCenterTheme.Chip(
            checkColor: self.checkColor?.toColor(),
            borderColor: self.borderColor?.toColor(),
            labelAppearance: self.labelAppearance?.toTextApperance()
        )
    }
}

fileprivate extension _PreferenceCenterThemeObjc.NavigationBar {
    func toNavigationBar() -> PreferenceCenterTheme.NavigationBar {
        return PreferenceCenterTheme.NavigationBar(
            title: self.title,
            titleFont: self.titleFont,
            titleColor: self.titleColor,
            tintColor: self.tintColor,
            backgroundColor: self.backgroundColor
        )
    }
}

fileprivate extension _PreferenceCenterThemeObjc.CommonSection {
    func toCommonSection() -> PreferenceCenterTheme.CommonSection {
        return PreferenceCenterTheme.CommonSection(
            titleAppearance: self.titleAppearance?.toTextApperance(),
            subtitleAppearance: self.subtitleAppearance?.toTextApperance()
        )
    }
}

fileprivate extension _PreferenceCenterThemeObjc.LabeledSectionBreak {
    func toLabeledSectionBreak() -> PreferenceCenterTheme.LabeledSectionBreak {
        return PreferenceCenterTheme.LabeledSectionBreak(
            titleAppearance: self.titleAppearance?.toTextApperance(),
            backgroundColor: self.backgroundColor?.toColor()
        )
    }
}


fileprivate extension _PreferenceCenterThemeObjc.ChannelSubscription {
    func toChannelSubscription() -> PreferenceCenterTheme.ChannelSubscription {
        return PreferenceCenterTheme.ChannelSubscription(
            titleAppearance: self.titleAppearance?.toTextApperance(),
            subtitleAppearance: self.subtitleAppearance?.toTextApperance(),
            toggleTintColor: self.toggleTintColor?.toColor()
        )
    }
}

fileprivate extension _PreferenceCenterThemeObjc.ContactSubscription {
    func toContactSubscription() -> PreferenceCenterTheme.ContactSubscription {
        return PreferenceCenterTheme.ContactSubscription(
            titleAppearance: self.titleAppearance?.toTextApperance(),
            subtitleAppearance: self.subtitleAppearance?.toTextApperance(),
            toggleTintColor: self.toggleTintColor?.toColor()
        )
    }
}

fileprivate extension _PreferenceCenterThemeObjc.ContactSubscriptionGroup {
    func toContactSubscriptionGroup() -> PreferenceCenterTheme.ContactSubscriptionGroup {
        return PreferenceCenterTheme.ContactSubscriptionGroup(
            titleAppearance: self.titleAppearance?.toTextApperance(),
            subtitleAppearance: self.subtitleAppearance?.toTextApperance(),
            chip: self.chip?.toChip()
        )
    }
}

fileprivate extension _PreferenceCenterThemeObjc.Alert {
    func toAlert() -> PreferenceCenterTheme.Alert {
        return PreferenceCenterTheme.Alert(
            titleAppearance: self.titleAppearance?.toTextApperance(),
            subtitleAppearance: self.subtitleAppearance?.toTextApperance(),
            buttonLabelAppearance: self.buttonLabelAppearance?.toTextApperance(),
            buttonBackgroundColor: self.buttonBackgroundColor?.toColor()
        )
    }
}

fileprivate extension _PreferenceCenterThemeObjc.PreferenceCenter {
    func toPreferenceCenter() -> PreferenceCenterTheme.PreferenceCenter {
        return PreferenceCenterTheme.PreferenceCenter(
            subtitleAppearance: self.subtitleAppearance?.toTextApperance(),
            retryButtonBackgroundColor: self.retryButtonBackgroundColor?.toColor(),
            retryButtonLabelAppearance: self.retryButtonLabelAppearance?.toTextApperance(),
            retryButtonLabel: self.retryButtonLabel,
            retryMessage: self.retryMessage,
            retryMessageAppearance: self.retryMessageAppearance?.toTextApperance()
        )
    }
}

fileprivate extension _PreferenceCenterThemeObjc.ViewController {
    func toViewController() -> PreferenceCenterTheme.ViewController {
        return PreferenceCenterTheme.ViewController(
            navigationBar: self.navigationBar?.toNavigationBar(),
            backgroundColor: self.backgroundColor
        )
    }
}

extension _PreferenceCenterThemeObjc {
    func toPreferenceCenterTheme() -> PreferenceCenterTheme {
        return PreferenceCenterTheme(
            viewController: self.viewController?.toViewController(),
            preferenceCenter: self.preferenceCenter?.toPreferenceCenter(),
            commonSection: self.commonSection?.toCommonSection(),
            labeledSectionBreak: self.labeledSectionBreak?.toLabeledSectionBreak(),
            alert: self.alert?.toAlert(),
            channelSubscription: self.channelSubscription?.toChannelSubscription(),
            contactSubscription: self.contactSubscription?.toContactSubscription(),
            contactSubscriptionGroup: self.contactSubscriptionGroup?.toContactSubscriptionGroup()
        )
    }
}


