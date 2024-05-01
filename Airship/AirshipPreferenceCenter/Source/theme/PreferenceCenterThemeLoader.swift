/* Copyright Airship and Contributors */

import Foundation
import SwiftUI

#if canImport(AirshipCore)
import AirshipCore
#endif

struct PreferenceCenterThemeLoader {
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

    static func fromPlist(_ file: String, bundle: Bundle = Bundle.main) throws
        -> PreferenceCenterTheme
    {
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
        let title: String?
        let titleFont: FontConfig?
        let titleColor: String?
        let navigationBarColor: String?
        let backgroundColor: String?
        let tintColor: String?
        let subtitleFont: FontConfig?
        let subtitleColor: String?
        let sectionTextColor: String?
        let sectionTextFont: FontConfig?
        let sectionTitleTextColor: String?
        let sectionTitleTextFont: FontConfig?
        let sectionSubtitleTextColor: String?
        let sectionSubtitleTextFont: FontConfig?
        let sectionBreakTextColor: String?
        let sectionBreakTextFont: FontConfig?
        let sectionBreakBackgroundColor: String?
        let preferenceTextColor: String?
        let preferenceTextFont: FontConfig?
        let preferenceTitleTextColor: String?
        let preferenceTitleTextFont: FontConfig?
        let preferenceSubtitleTextColor: String?
        let preferenceSubtitleTextFont: FontConfig?

        let switchTintColor: String?

        let preferenceChipTextColor: String?
        let preferenceChipTextFont: FontConfig?
        let preferenceChipCheckmarkCheckedBackgroundColor: String?
        let preferenceChipBorderColor: String?

        let alertTitleColor: String?
        let alertTitleFont: FontConfig?
        let alertSubtitleColor: String?
        let alertSubtitleFont: FontConfig?
        let alertButtonBackgroundColor: String?
        let alertButtonLabelColor: String?
        let alertButtonLabelFont: FontConfig?
    }

    fileprivate struct Config: Decodable {
        let viewController: ViewController?
        let preferenceCenter: PreferenceCenter?
        let commonSection: CommonSection?
        let labeledSectionBreak: LabeledSectionBreak?
        let alert: Alert?
        let channelSubscription: ChannelSubscription?
        let contactSubscription: ContactSubscription?
        let contactSubscriptionGroup: ContactSubscriptionGroup?

        struct NavigationBar: Decodable {
            let title: String?
            let titleFont: FontConfig?
            let titleColor: String?
            let tintColor: String?
            let backgroundColor: String?
        }

        struct ViewController: Decodable {
            let navigationBar: NavigationBar?
            let backgroundColor: String?
        }

        struct PreferenceCenter: Decodable {
            let subtitleAppearance: TextAppearance?
            let retryButtonBackgroundColor: String?
            let retryButtonLabelAppearance: TextAppearance?
            let retryButtonLabel: String?
            let retryMessage: String?
            let retryMessageAppearance: TextAppearance?
        }

        struct TextAppearance: Decodable {
            let font: FontConfig?
            let color: String?
        }

        struct Chip: Decodable {
            let checkColor: String?
            let borderColor: String?
            let labelAppearance: TextAppearance?
        }

        struct CommonSection: Decodable {
            let titleAppearance: TextAppearance?
            let subtitleAppearance: TextAppearance?
        }

        struct LabeledSectionBreak: Decodable {
            let titleAppearance: TextAppearance?
            let backgroundColor: String?
        }

        struct Alert: Decodable {
            let titleAppearance: TextAppearance?
            let subtitleAppearance: TextAppearance?
            let buttonLabelAppearance: TextAppearance?
            let buttonBackgroundColor: String?
        }

        struct ChannelSubscription: Decodable {
            let titleAppearance: TextAppearance?
            let subtitleAppearance: TextAppearance?
            let toggleTintColor: String?
            let buttonBackgroundColor: String?
        }

        struct ContactSubscription: Decodable {
            let titleAppearance: TextAppearance?
            let subtitleAppearance: TextAppearance?
            let toggleTintColor: String?
        }

        struct ContactSubscriptionGroup: Decodable {
            let titleAppearance: TextAppearance?
            let subtitleAppearance: TextAppearance?
            let chip: Chip?
        }
    }

    fileprivate struct FontConfig: Decodable {
        let fontName: String
        let fontSize: String
    }
}

extension String {
    fileprivate func toUIColor() -> UIColor? {
        let colorString = self.trimmingCharacters(in: .whitespaces)
        if let uiColor = AirshipColorUtils.color(colorString) {
            return uiColor
        }

        return UIColor(named: self)
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
    func toTextApperance() throws -> PreferenceCenterTheme.TextAppearance {
        return PreferenceCenterTheme.TextAppearance(
            font: try self.font?.toFont(),
            color: self.color?.airshipToColor()
        )
    }
}

extension PreferenceCenterThemeLoader.Config.Chip {
    func toChip() throws -> PreferenceCenterTheme.Chip {
        return PreferenceCenterTheme.Chip(
            checkColor: self.checkColor?.airshipToColor(),
            borderColor: self.borderColor?.airshipToColor(),
            labelAppearance: try self.labelAppearance?.toTextApperance()
        )
    }
}

extension PreferenceCenterThemeLoader.Config.NavigationBar {
    func toNavigationBar() throws -> PreferenceCenterTheme.NavigationBar {
        return PreferenceCenterTheme.NavigationBar(
            title: self.title,
            backgroundColor: self.backgroundColor?.toUIColor()
        )
    }
}

extension PreferenceCenterThemeLoader.Config.CommonSection {
    func toCommonSection() throws -> PreferenceCenterTheme.CommonSection {
        return PreferenceCenterTheme.CommonSection(
            titleAppearance: try self.titleAppearance?.toTextApperance(),
            subtitleAppearance: try self.subtitleAppearance?.toTextApperance()
        )
    }
}

extension PreferenceCenterThemeLoader.Config.LabeledSectionBreak {
    func toLabeledSectionBreak() throws
        -> PreferenceCenterTheme.LabeledSectionBreak
    {
        return PreferenceCenterTheme.LabeledSectionBreak(
            titleAppearance: try self.titleAppearance?.toTextApperance(),
            backgroundColor: self.backgroundColor?.airshipToColor()
        )
    }
}

extension PreferenceCenterThemeLoader.Config.ChannelSubscription {
    func toChannelSubscription() throws
        -> PreferenceCenterTheme.ChannelSubscription
    {
        return PreferenceCenterTheme.ChannelSubscription(
            titleAppearance: try self.titleAppearance?.toTextApperance(),
            subtitleAppearance: try self.subtitleAppearance?.toTextApperance(),
            toggleTintColor: self.toggleTintColor?.airshipToColor()
        )
    }
}

extension PreferenceCenterThemeLoader.Config.ContactSubscription {
    func toContactSubscription() throws
        -> PreferenceCenterTheme.ContactSubscription
    {
        return PreferenceCenterTheme.ContactSubscription(
            titleAppearance: try self.titleAppearance?.toTextApperance(),
            subtitleAppearance: try self.subtitleAppearance?.toTextApperance(),
            toggleTintColor: self.toggleTintColor?.airshipToColor()
        )
    }
}

extension PreferenceCenterThemeLoader.Config.ContactSubscriptionGroup {
    func toContactSubscriptionGroup() throws
        -> PreferenceCenterTheme.ContactSubscriptionGroup
    {
        return PreferenceCenterTheme.ContactSubscriptionGroup(
            titleAppearance: try self.titleAppearance?.toTextApperance(),
            subtitleAppearance: try self.subtitleAppearance?.toTextApperance(),
            chip: try self.chip?.toChip()
        )
    }
}

extension PreferenceCenterThemeLoader.Config.Alert {
    func toAlert() throws -> PreferenceCenterTheme.Alert {
        return PreferenceCenterTheme.Alert(
            titleAppearance: try self.titleAppearance?.toTextApperance(),
            subtitleAppearance: try self.subtitleAppearance?.toTextApperance(),
            buttonLabelAppearance: try self.buttonLabelAppearance?
                .toTextApperance(),
            buttonBackgroundColor: self.buttonBackgroundColor?.airshipToColor()
        )
    }
}

extension PreferenceCenterThemeLoader.Config.PreferenceCenter {
    func toPreferenceCenter() throws -> PreferenceCenterTheme.PreferenceCenter {
        return PreferenceCenterTheme.PreferenceCenter(
            subtitleAppearance: try self.subtitleAppearance?.toTextApperance(),
            retryButtonBackgroundColor: self.retryButtonBackgroundColor?
                .airshipToColor(),
            retryButtonLabelAppearance: try self.retryButtonLabelAppearance?
                .toTextApperance(),
            retryButtonLabel: self.retryButtonLabel,
            retryMessage: self.retryMessage,
            retryMessageAppearance: try self.retryMessageAppearance?
                .toTextApperance()
        )
    }
}

extension PreferenceCenterThemeLoader.Config.ViewController {
    func toViewController() throws -> PreferenceCenterTheme.ViewController {
        return PreferenceCenterTheme.ViewController(
            navigationBar: try self.navigationBar?.toNavigationBar(),
            backgroundColor: self.backgroundColor?.toUIColor()
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
                .airshipToColor()
        )

        let preferenceSubtitle = PreferenceCenterTheme.TextAppearance(
            font: try
                (self.preferenceSubtitleTextFont ?? self.preferenceTextFont)?
                .toFont(),
            color: (self.preferenceSubtitleTextColor ?? self.preferenceTextColor)?
                .airshipToColor()
        )

        return PreferenceCenterTheme(
            viewController: PreferenceCenterTheme.ViewController(
                navigationBar: PreferenceCenterTheme.NavigationBar(
                    title: self.title,
                    backgroundColor: self.navigationBarColor?.toUIColor()
                ),
                backgroundColor: self.backgroundColor?.toUIColor()
            ),
            preferenceCenter: PreferenceCenterTheme.PreferenceCenter(
                subtitleAppearance: PreferenceCenterTheme.TextAppearance(
                    font: try self.subtitleFont?.toFont(),
                    color: self.subtitleColor?.airshipToColor()
                )
            ),
            commonSection: PreferenceCenterTheme.CommonSection(
                titleAppearance: PreferenceCenterTheme.TextAppearance(
                    font: try
                        (self.sectionTitleTextFont ?? self.sectionTextFont)?
                        .toFont(),
                    color: (self.sectionTitleTextColor ?? self.sectionTextColor)?
                        .airshipToColor()
                ),
                subtitleAppearance: PreferenceCenterTheme.TextAppearance(
                    font: try
                        (self.sectionSubtitleTextFont ?? self.sectionTextFont)?
                        .toFont(),
                    color: (self.sectionSubtitleTextColor
                        ?? self.sectionTextColor)?
                        .airshipToColor()
                )
            ),
            labeledSectionBreak: PreferenceCenterTheme.LabeledSectionBreak(
                titleAppearance: PreferenceCenterTheme.TextAppearance(
                    font: try
                        (self.sectionBreakTextFont ?? self.sectionTextFont)?
                        .toFont(),
                    color: (self.sectionBreakTextColor ?? self.sectionTextColor)?
                        .airshipToColor()
                ),
                backgroundColor: self.sectionBreakBackgroundColor?.airshipToColor()
            ),
            alert: PreferenceCenterTheme.Alert(
                titleAppearance: PreferenceCenterTheme.TextAppearance(
                    font: try self.alertTitleFont?.toFont(),
                    color: self.alertTitleColor?.airshipToColor()
                ),
                subtitleAppearance: PreferenceCenterTheme.TextAppearance(
                    font: try self.alertSubtitleFont?.toFont(),
                    color: self.alertSubtitleColor?.airshipToColor()
                ),
                buttonLabelAppearance: PreferenceCenterTheme.TextAppearance(
                    font: try self.alertButtonLabelFont?.toFont(),
                    color: self.alertButtonLabelColor?.airshipToColor()
                ),
                buttonBackgroundColor: self.alertButtonBackgroundColor?
                    .airshipToColor()
            ),
            channelSubscription: PreferenceCenterTheme.ChannelSubscription(
                titleAppearance: preferenceTitle,
                subtitleAppearance: preferenceSubtitle,
                toggleTintColor: self.preferenceTextColor?.airshipToColor()
            ),
            contactSubscription: PreferenceCenterTheme.ContactSubscription(
                titleAppearance: preferenceTitle,
                subtitleAppearance: preferenceSubtitle,
                toggleTintColor: self.preferenceTextColor?.airshipToColor()
            ),
            contactSubscriptionGroup:
                PreferenceCenterTheme.ContactSubscriptionGroup(
                    titleAppearance: preferenceTitle,
                    subtitleAppearance: preferenceSubtitle,
                    chip: PreferenceCenterTheme.Chip(
                        checkColor: self
                            .preferenceChipCheckmarkCheckedBackgroundColor?
                            .airshipToColor(),
                        borderColor: self.preferenceChipBorderColor?.airshipToColor(),
                        labelAppearance: PreferenceCenterTheme.TextAppearance(
                            font: try self.preferenceChipTextFont?.toFont(),
                            color: self.preferenceChipTextColor?.airshipToColor()
                        )
                    )
                )
        )
    }
}
