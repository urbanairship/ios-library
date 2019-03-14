/* Copyright Urban Airship and Contributors */

import UIKit

public class Theme: NSObject {
    private struct Palette {
        static let SunGold:UIColor = #colorLiteral(red: 0.9191198945, green: 0.6654229164, blue: 0.008443674073, alpha: 1)
        static let CloudWhite:UIColor = #colorLiteral(red: 0.999904573, green: 1, blue: 0.9998808503, alpha: 1)
        static let Aluminum:UIColor = #colorLiteral(red: 0.6861566305, green: 0.7064983249, blue: 0.7104164958, alpha: 1)
        static let Steel:UIColor = #colorLiteral(red: 0.3534885049, green: 0.441475302, blue: 0.4575318098, alpha: 1)
        static let Gunmetal:UIColor = #colorLiteral(red: 0.2361389995, green: 0.2875766158, blue: 0.2998327017, alpha: 1)
        static let Charcoal:UIColor = #colorLiteral(red: 0.174015671, green: 0.2047065496, blue: 0.2129232585, alpha: 1)
        static let SmoggySkyBlue:UIColor = #colorLiteral(red: 0.5018063188, green: 0.7903521657, blue: 0.8603001237, alpha: 1)
        static let StormBlue:UIColor = #colorLiteral(red: 0, green: 0.4109853506, blue: 0.5627535582, alpha: 1)
    }

    @objc public var Background:UIColor = Palette.Gunmetal
    @objc public var WidgetTint:UIColor = Palette.SmoggySkyBlue
    @objc public var ButtonBackground:UIColor = Palette.SunGold
    @objc public var ButtonText:UIColor = Palette.CloudWhite
    @objc public var NavigationBarBackground:UIColor = Palette.StormBlue
    @objc public var PrimaryText:UIColor = Palette.CloudWhite
    @objc public var SecondaryText:UIColor = Palette.Aluminum
    @objc public var TabBarBackground:UIColor = Palette.Charcoal
    @objc public var TabBarDeselectedTint:UIColor = Palette.Steel
    @objc public var TabBarSelectedTint:UIColor = Palette.SunGold
}
