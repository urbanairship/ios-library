/* Copyright Airship and Contributors */

import Foundation
@_spi(AirshipInternal) import AirshipBasement
import SwiftUI

import AirshipCore

struct PreferenceCenterThemeLoader {
    // Existing code remains unchanged
    static func defaultPlist() -> PreferenceCenterTheme? {
        if let _ = try? plistPath(
            file: "AirshipPreferenceCenterTheme",
            bundle: Bundle.main
        ) {
            do {
                return try fromPlist("AirshipPreferenceCenterTheme")
            } catch {
                AirshipLogger.error(
                    "Unable to load preference center theme \(error)"
                )
            }
        } else if let _ = try? plistPath(
            file: "AirshipPreferenceCenterStyle",
            bundle: Bundle.main
        ) {
            do {
                return try fromPlist("AirshipPreferenceCenterStyle")
            } catch {
                AirshipLogger.error(
                    "Unable to load preference center theme \(error)"
                )
            }
        }

        return nil
    }

    static func fromPlist(
        _ file: String,
        bundle: Bundle = Bundle.main
    ) throws -> PreferenceCenterTheme {
        let path = try plistPath(file: file, bundle: bundle)

        guard let data = FileManager.default.contents(atPath: path) else {
            throw AirshipErrors.error("Failed to load contents of theme.")
        }

        let decoder = PropertyListDecoder()

        let config = try decoder.decode(Config.self, from: data)
        guard config.isEmpty else {
            return try config.toPreferenceCenterTheme()
        }
        let legacy = try decoder.decode(LegacyConfig.self, from: data)
        return try legacy.toPreferenceCenterTheme()
    }

    static func plistPath(file: String, bundle: Bundle) throws -> String {
        guard let path = bundle.path(forResource: file, ofType: "plist"),
              FileManager.default.fileExists(atPath: path)
        else {
            throw AirshipErrors.error("File not found \(file).")
        }

        return path
    }

    fileprivate struct LegacyConfig: Decodable {
        // Existing properties remain unchanged
        private let title: String?
        private let titleFont: FontConfig?
        private let titleColor: String?
        private let navigationBarColor: String?
        private let backgroundColor: String?
        private let tintColor: String?
        private let subtitleFont: FontConfig?
        private let subtitleColor: String?
        private let sectionTextColor: String?
        private let sectionTextFont: FontConfig?
        private let sectionTitleTextColor: String?
        private let sectionTitleTextFont: FontConfig?
        private let sectionSubtitleTextColor: String?
        private let sectionSubtitleTextFont: FontConfig?
        private let sectionBreakTextColor: String?
        private let sectionBreakTextFont: FontConfig?
        private let sectionBreakBackgroundColor: String?
        private let preferenceTextColor: String?
        private let preferenceTextFont: FontConfig?
        private let preferenceTitleTextColor: String?
        private let preferenceTitleTextFont: FontConfig?
        private let preferenceSubtitleTextColor: String?
        private let preferenceSubtitleTextFont: FontConfig?

        private let switchTintColor: String?

        private let preferenceChipTextColor: String?
        private let preferenceChipTextFont: FontConfig?
        private let preferenceChipCheckmarkCheckedBackgroundColor: String?
        private let preferenceChipBorderColor: String?

        private let alertTitleColor: String?
        private let alertTitleFont: FontConfig?
        private let alertSubtitleColor: String?
        private let alertSubtitleFont: FontConfig?
        private let alertButtonBackgroundColor: String?
        private let alertButtonLabelColor: String?
        private let alertButtonLabelFont: FontConfig?

        // New properties for dark mode
        private let titleColorDark: String?
        private let navigationBarColorDark: String?
        private let backgroundColorDark: String?
        private let tintColorDark: String?
        private let subtitleColorDark: String?
        private let sectionTextColorDark: String?
        private let sectionTitleTextColorDark: String?
        private let sectionSubtitleTextColorDark: String?
        private let sectionBreakTextColorDark: String?
        private let sectionBreakBackgroundColorDark: String?
        private let preferenceTextColorDark: String?
        private let preferenceTitleTextColorDark: String?
        private let preferenceSubtitleTextColorDark: String?
        private let switchTintColorDark: String?
        private let preferenceChipTextColorDark: String?
        private let preferenceChipCheckmarkCheckedBackgroundColorDark: String?
        private let preferenceChipBorderColorDark: String?
        private let alertTitleColorDark: String?
        private let alertSubtitleColorDark: String?
        private let alertButtonBackgroundColorDark: String?
        private let alertButtonLabelColorDark: String?
    }

    fileprivate struct Config: Decodable {
        private let viewController: ViewController?
        private let preferenceCenter: PreferenceCenter?
        private let commonSection: CommonSection?
        private let labeledSectionBreak: LabeledSectionBreak?
        private let alert: Alert?
        private let channelSubscription: ChannelSubscription?
        private let contactSubscription: ContactSubscription?
        private let contactSubscriptionGroup: ContactSubscriptionGroup?

        struct NavigationBar: Decodable {
            private let title: String?
            private let titleFont: FontConfig?
            private let titleColor: String?
            private let titleColorDark: String?
            private let tintColor: String?
            private let tintColorDark: String?
            private let backgroundColor: String?
            private let backgroundColorDark: String?
            private let backButtonColor: String?
            private let backButtonColorDark: String?
        }

        struct ViewController: Decodable {
            private let navigationBar: NavigationBar?
            private let backgroundColor: String?
            private let backgroundColorDark: String?
        }

        struct PreferenceCenter: Decodable {
            private let subtitleAppearance: TextAppearance?
            private let retryButtonBackgroundColor: String?
            private let retryButtonBackgroundColorDark: String?
            private let retryButtonLabelAppearance: TextAppearance?
            private let retryButtonLabel: String?
            private let retryMessage: String?
            private let retryMessageAppearance: TextAppearance?
        }

        struct TextAppearance: Decodable {
            private let font: FontConfig?
            private let color: String?
            private let colorDark: String?
        }

        struct Chip: Decodable {
            private let checkColor: String?
            private let checkColorDark: String?
            private let borderColor: String?
            private let borderColorDark: String?
            private let labelAppearance: TextAppearance?
        }

        struct CommonSection: Decodable {
            private let titleAppearance: TextAppearance?
            private let subtitleAppearance: TextAppearance?
        }

        struct LabeledSectionBreak: Decodable {
            private let titleAppearance: TextAppearance?
            private let backgroundColor: String?
            private let backgroundColorDark: String?
        }

        struct Alert: Decodable {
            private let titleAppearance: TextAppearance?
            private let subtitleAppearance: TextAppearance?
            private let buttonLabelAppearance: TextAppearance?
            private let buttonBackgroundColor: String?
            private let buttonBackgroundColorDark: String?
        }

        struct ChannelSubscription: Decodable {
            private let titleAppearance: TextAppearance?
            private let subtitleAppearance: TextAppearance?
            private let toggleTintColor: String?
            private let toggleTintColorDark: String?
            private let buttonBackgroundColor: String?
            private let buttonBackgroundColorDark: String?
        }

        struct ContactSubscription: Decodable {
            private let titleAppearance: TextAppearance?
            private let subtitleAppearance: TextAppearance?
            private let toggleTintColor: String?
            private let toggleTintColorDark: String?
        }

        struct ContactSubscriptionGroup: Decodable {
            private let titleAppearance: TextAppearance?
            private let subtitleAppearance: TextAppearance?
            private let chip: Chip?
        }
    }

    fileprivate struct FontConfig: Decodable {
        private let fontName: String
        private let fontSize: String
    }
}


extension PreferenceCenterThemeLoader.FontConfig {
    fileprivate func toFont() throws -> Font {
        guard
            let fontSize = Double(
                fontSize.trimmingCharacters(in: .whitespaces)
            ),
            fontSize > 0.0
        else {
            throw AirshipErrors.error(
                "Font size must represent a double greater than 0"
            )
        }

        return Font.custom(
            fontName.trimmingCharacters(in: .whitespaces),
            size: fontSize
        )
    }
}

extension PreferenceCenterThemeLoader.Config.TextAppearance {
    func toTextAppearance() throws -> PreferenceCenterTheme.TextAppearance {
        return PreferenceCenterTheme.TextAppearance(
            font: try self.font?.toFont(),
            color: self.color?.airshipToColor(),
            colorDark: self.colorDark?.airshipToColor()
        )
    }
}

extension PreferenceCenterThemeLoader.Config.Chip {
    func toChip() throws -> PreferenceCenterTheme.Chip {
        return PreferenceCenterTheme.Chip(
            checkColor: self.checkColor?.airshipToColor(),
            checkColorDark: self.checkColorDark?.airshipToColor(),
            borderColor: self.borderColor?.airshipToColor(),
            borderColorDark: self.borderColorDark?.airshipToColor(),
            labelAppearance: try self.labelAppearance?.toTextAppearance()
        )
    }
}

extension PreferenceCenterThemeLoader.Config.NavigationBar {
    func toNavigationBar() throws -> PreferenceCenterTheme.NavigationBar {
        return PreferenceCenterTheme.NavigationBar(
            title: self.title,
            backgroundColor: self.backgroundColor?.airshipHexToNativeColor(),
            backgroundColorDark: self.backgroundColorDark?.airshipHexToNativeColor(),
            backButtonColor: self.backButtonColor?.airshipHexToNativeColor(),
            backButtonColorDark: self.backButtonColorDark?.airshipHexToNativeColor()
        )
    }
}

extension PreferenceCenterThemeLoader.Config.CommonSection {
    func toCommonSection() throws -> PreferenceCenterTheme.CommonSection {
        return PreferenceCenterTheme.CommonSection(
            titleAppearance: try self.titleAppearance?.toTextAppearance(),
            subtitleAppearance: try self.subtitleAppearance?.toTextAppearance()
        )
    }
}

extension PreferenceCenterThemeLoader.Config.LabeledSectionBreak {
    func toLabeledSectionBreak() throws
    -> PreferenceCenterTheme.LabeledSectionBreak
    {
        return PreferenceCenterTheme.LabeledSectionBreak(
            titleAppearance: try self.titleAppearance?.toTextAppearance(),
            backgroundColor: self.backgroundColor?.airshipToColor(),
            backgroundColorDark: self.backgroundColorDark?.airshipToColor()
        )
    }
}

extension PreferenceCenterThemeLoader.Config.ChannelSubscription {
    func toChannelSubscription() throws
    -> PreferenceCenterTheme.ChannelSubscription
    {
        return PreferenceCenterTheme.ChannelSubscription(
            titleAppearance: try self.titleAppearance?.toTextAppearance(),
            subtitleAppearance: try self.subtitleAppearance?.toTextAppearance(),
            toggleTintColor: self.toggleTintColor?.airshipToColor(),
            toggleTintColorDark: self.toggleTintColorDark?.airshipToColor()
        )
    }
}

extension PreferenceCenterThemeLoader.Config.ContactSubscription {
    func toContactSubscription() throws
    -> PreferenceCenterTheme.ContactSubscription
    {
        return PreferenceCenterTheme.ContactSubscription(
            titleAppearance: try self.titleAppearance?.toTextAppearance(),
            subtitleAppearance: try self.subtitleAppearance?.toTextAppearance(),
            toggleTintColor: self.toggleTintColor?.airshipToColor(),
            toggleTintColorDark: self.toggleTintColorDark?.airshipToColor()
        )
    }
}

extension PreferenceCenterThemeLoader.Config.ContactSubscriptionGroup {
    func toContactSubscriptionGroup() throws
    -> PreferenceCenterTheme.ContactSubscriptionGroup
    {
        return PreferenceCenterTheme.ContactSubscriptionGroup(
            titleAppearance: try self.titleAppearance?.toTextAppearance(),
            subtitleAppearance: try self.subtitleAppearance?.toTextAppearance(),
            chip: try self.chip?.toChip()
        )
    }
}

extension PreferenceCenterThemeLoader.Config.Alert {
    func toAlert() throws -> PreferenceCenterTheme.Alert {
        return PreferenceCenterTheme.Alert(
            titleAppearance: try self.titleAppearance?.toTextAppearance(),
            subtitleAppearance: try self.subtitleAppearance?.toTextAppearance(),
            buttonLabelAppearance: try self.buttonLabelAppearance?.toTextAppearance(),
            buttonBackgroundColor: self.buttonBackgroundColor?.airshipToColor(),
            buttonBackgroundColorDark: self.buttonBackgroundColorDark?.airshipToColor()
        )
    }
}

extension PreferenceCenterThemeLoader.Config.PreferenceCenter {
    func toPreferenceCenter() throws -> PreferenceCenterTheme.PreferenceCenter {
        return PreferenceCenterTheme.PreferenceCenter(
            subtitleAppearance: try self.subtitleAppearance?.toTextAppearance(),
            retryButtonBackgroundColor: self.retryButtonBackgroundColor?
                .airshipToColor(),
            retryButtonBackgroundColorDark: self.retryButtonBackgroundColorDark?
                .airshipToColor(),
            retryButtonLabelAppearance: try self.retryButtonLabelAppearance?
                .toTextAppearance(),
            retryButtonLabel: self.retryButtonLabel,
            retryMessage: self.retryMessage,
            retryMessageAppearance: try self.retryMessageAppearance?
                .toTextAppearance()
        )
    }
}

extension PreferenceCenterThemeLoader.Config.ViewController {
    func toViewController() throws -> PreferenceCenterTheme.ViewController {
        return PreferenceCenterTheme.ViewController(
            navigationBar: try self.navigationBar?.toNavigationBar(),
            backgroundColor: self.backgroundColor?.airshipHexToNativeColor(),
            backgroundColorDark: self.backgroundColorDark?.airshipHexToNativeColor()
        )
    }
}

extension PreferenceCenterThemeLoader.Config {
    fileprivate var isEmpty: Bool {
        guard self.viewController == nil else { return false }
        guard self.preferenceCenter == nil else { return false }
        guard self.commonSection == nil else { return false }
        guard self.labeledSectionBreak == nil else { return false }
        guard self.alert == nil else { return false }
        guard self.channelSubscription == nil else { return false }
        guard self.contactSubscription == nil else { return false }
        guard self.contactSubscriptionGroup == nil else { return false }
        return true
    }

    fileprivate func toPreferenceCenterTheme() throws -> PreferenceCenterTheme {
        return PreferenceCenterTheme(
            viewController: try self.viewController?.toViewController(),
            preferenceCenter: try self.preferenceCenter?.toPreferenceCenter(),
            commonSection: try self.commonSection?.toCommonSection(),
            labeledSectionBreak: try self.labeledSectionBreak?
                .toLabeledSectionBreak(),
            alert: try self.alert?.toAlert(),
            channelSubscription: try self.channelSubscription?
                .toChannelSubscription(),
            contactSubscription: try self.contactSubscription?
                .toContactSubscription(),
            contactSubscriptionGroup: try self.contactSubscriptionGroup?
                .toContactSubscriptionGroup()
        )
    }
}

extension PreferenceCenterThemeLoader.LegacyConfig {
    fileprivate func toPreferenceCenterTheme() throws -> PreferenceCenterTheme {
        let preferenceTitle = PreferenceCenterTheme.TextAppearance(
            font: try (self.preferenceTitleTextFont ?? self.preferenceTextFont)?
                .toFont(),
            color: (self.preferenceTitleTextColor ?? self.preferenceTextColor)?
                .airshipToColor(),
            colorDark: (self.preferenceTitleTextColorDark ?? self.preferenceTextColorDark)?
                .airshipToColor()
        )

        let preferenceSubtitle = PreferenceCenterTheme.TextAppearance(
            font: try
            (self.preferenceSubtitleTextFont ?? self.preferenceTextFont)?
                .toFont(),
            color: (self.preferenceSubtitleTextColor ?? self.preferenceTextColor)?
                .airshipToColor(),
            colorDark: (self.preferenceSubtitleTextColorDark ?? self.preferenceTextColorDark)?
                .airshipToColor()
        )

        return PreferenceCenterTheme(
            viewController: PreferenceCenterTheme.ViewController(
                navigationBar: PreferenceCenterTheme.NavigationBar(
                    title: self.title,
                    backgroundColor: self.navigationBarColor?.airshipHexToNativeColor(),
                    backgroundColorDark: self.navigationBarColorDark?.airshipHexToNativeColor()
                ),
                backgroundColor: self.backgroundColor?.airshipHexToNativeColor(),
                backgroundColorDark: self.backgroundColorDark?.airshipHexToNativeColor()
            ),
            preferenceCenter: PreferenceCenterTheme.PreferenceCenter(
                subtitleAppearance: PreferenceCenterTheme.TextAppearance(
                    font: try self.subtitleFont?.toFont(),
                    color: self.subtitleColor?.airshipToColor(),
                    colorDark: self.subtitleColorDark?.airshipToColor()
                )
            ),
            commonSection: PreferenceCenterTheme.CommonSection(
                titleAppearance: PreferenceCenterTheme.TextAppearance(
                    font: try
                    (self.sectionTitleTextFont ?? self.sectionTextFont)?
                        .toFont(),
                    color: (self.sectionTitleTextColor ?? self.sectionTextColor)?
                        .airshipToColor(),
                    colorDark: (self.sectionTitleTextColorDark ?? self.sectionTextColorDark)?
                        .airshipToColor()
                ),
                subtitleAppearance: PreferenceCenterTheme.TextAppearance(
                    font: try
                    (self.sectionSubtitleTextFont ?? self.sectionTextFont)?
                        .toFont(),
                    color: (self.sectionSubtitleTextColor
                            ?? self.sectionTextColor)?
                        .airshipToColor(),
                    colorDark: (self.sectionSubtitleTextColorDark
                                ?? self.sectionTextColorDark)?
                        .airshipToColor()
                )
            ),
            labeledSectionBreak: PreferenceCenterTheme.LabeledSectionBreak(
                titleAppearance: PreferenceCenterTheme.TextAppearance(
                    font: try
                    (self.sectionBreakTextFont ?? self.sectionTextFont)?
                        .toFont(),
                    color: (self.sectionBreakTextColor ?? self.sectionTextColor)?
                        .airshipToColor(),
                    colorDark: (self.sectionBreakTextColorDark ?? self.sectionTextColorDark)?
                        .airshipToColor()
                ),
                backgroundColor: self.sectionBreakBackgroundColor?.airshipToColor(),
                backgroundColorDark: self.sectionBreakBackgroundColorDark?.airshipToColor()
            ),
            alert: PreferenceCenterTheme.Alert(
                titleAppearance: PreferenceCenterTheme.TextAppearance(
                    font: try self.alertTitleFont?.toFont(),
                    color: self.alertTitleColor?.airshipToColor(),
                    colorDark: self.alertTitleColorDark?.airshipToColor()
                ),
                subtitleAppearance: PreferenceCenterTheme.TextAppearance(
                    font: try self.alertSubtitleFont?.toFont(),
                    color: self.alertSubtitleColor?.airshipToColor(),
                    colorDark: self.alertSubtitleColorDark?.airshipToColor()
                ),
                buttonLabelAppearance: PreferenceCenterTheme.TextAppearance(
                    font: try self.alertButtonLabelFont?.toFont(),
                    color: self.alertButtonLabelColor?.airshipToColor(),
                    colorDark: self.alertButtonLabelColorDark?.airshipToColor()
                ),
                buttonBackgroundColor: self.alertButtonBackgroundColor?
                    .airshipToColor(),
                buttonBackgroundColorDark: self.alertButtonBackgroundColorDark?
                    .airshipToColor()
            ),
            channelSubscription: PreferenceCenterTheme.ChannelSubscription(
                titleAppearance: preferenceTitle,
                subtitleAppearance: preferenceSubtitle,
                toggleTintColor: self.switchTintColor?.airshipToColor(),
                toggleTintColorDark: self.switchTintColorDark?.airshipToColor()
            ),
            contactSubscription: PreferenceCenterTheme.ContactSubscription(
                titleAppearance: preferenceTitle,
                subtitleAppearance: preferenceSubtitle,
                toggleTintColor: self.switchTintColor?.airshipToColor(),
                toggleTintColorDark: self.switchTintColorDark?.airshipToColor()
            ),
            contactSubscriptionGroup:
                PreferenceCenterTheme.ContactSubscriptionGroup(
                    titleAppearance: preferenceTitle,
                    subtitleAppearance: preferenceSubtitle,
                    chip: PreferenceCenterTheme.Chip(
                        checkColor: self
                            .preferenceChipCheckmarkCheckedBackgroundColor?
                            .airshipToColor(),
                        checkColorDark: self
                            .preferenceChipCheckmarkCheckedBackgroundColorDark?
                            .airshipToColor(),
                        borderColor: self.preferenceChipBorderColor?.airshipToColor(),
                        borderColorDark: self.preferenceChipBorderColorDark?.airshipToColor(),
                        labelAppearance: PreferenceCenterTheme.TextAppearance(
                            font: try self.preferenceChipTextFont?.toFont(),
                            color: self.preferenceChipTextColor?.airshipToColor(),
                            colorDark: self.preferenceChipTextColorDark?.airshipToColor()
                        )
                    )
                )
        )
    }
}
