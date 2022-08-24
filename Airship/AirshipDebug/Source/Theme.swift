/* Copyright Airship and Contributors */

import UIKit

public class Theme: NSObject {
    private struct Palette {
        static let SunsetRed:UIColor = #colorLiteral(red: 1, green: 0, blue: 0.1848241687, alpha: 1)
        static let AirshipBlue:UIColor = #colorLiteral(red: 0, green: 0.2950756848, blue: 0.9987069964, alpha: 1)
        static let CloudWhite:UIColor = #colorLiteral(red: 1, green: 1, blue: 1, alpha: 1)
        static let RainCloudWhite:UIColor = #colorLiteral(red: 0.9655779034, green: 0.9655779034, blue: 0.9655779034, alpha: 1)

        static let SpaceBlack:UIColor = #colorLiteral(red: 0, green: 0, blue: 0, alpha: 1)
        static let AlienGrey:UIColor = #colorLiteral(red: 0.513617754, green: 0.5134617686, blue: 0.529979229, alpha: 1)
    }

    @objc public var Background:UIColor = Palette.CloudWhite
    @objc public var SecondaryBackground:UIColor = Palette.RainCloudWhite

    @objc public var WidgetTint:UIColor = Palette.AirshipBlue
    @objc public var ButtonBackground:UIColor = Palette.AirshipBlue
    @objc public var ButtonText:UIColor = Palette.CloudWhite
    @objc public var PrimaryText:UIColor = Palette.SpaceBlack
    @objc public var SecondaryText:UIColor = Palette.AlienGrey
    @objc public var TabBarBackground:UIColor = Palette.CloudWhite
    @objc public var TabBarDeselectedTint:UIColor = Palette.CloudWhite
    @objc public var TabBarSelectedTint:UIColor = Palette.AirshipBlue
}
