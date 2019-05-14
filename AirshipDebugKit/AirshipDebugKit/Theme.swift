/* Copyright Airship and Contributors */

import UIKit

public class Theme: NSObject {
    private struct Palette {
        static let SunsetRed:UIColor = #colorLiteral(red: 1, green: 0, blue: 0.1848241687, alpha: 1)
        static let AirshipBlue:UIColor = #colorLiteral(red: 0, green: 0.2950756848, blue: 0.9987069964, alpha: 1)
        static let CloudWhite:UIColor = #colorLiteral(red: 0.999904573, green: 1, blue: 0.9998808503, alpha: 1)
        static let SpaceBlack:UIColor = #colorLiteral(red: 0, green: 0, blue: 0, alpha: 1)
    }

    @objc public var Background:UIColor = Palette.CloudWhite
    @objc public var WidgetTint:UIColor = Palette.AirshipBlue
    @objc public var ButtonBackground:UIColor = Palette.AirshipBlue
    @objc public var ButtonText:UIColor = Palette.CloudWhite
    @objc public var NavigationBarBackground:UIColor = Palette.SunsetRed
    @objc public var NavigationBarText:UIColor = Palette.CloudWhite
    @objc public var PrimaryText:UIColor = Palette.SpaceBlack
    @objc public var SecondaryText:UIColor = Palette.SpaceBlack
    @objc public var TabBarBackground:UIColor = Palette.CloudWhite
    @objc public var TabBarDeselectedTint:UIColor = Palette.CloudWhite
    @objc public var TabBarSelectedTint:UIColor = Palette.AirshipBlue
}
