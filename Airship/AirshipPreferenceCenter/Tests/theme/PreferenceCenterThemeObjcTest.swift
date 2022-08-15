/* Copyright Airship and Contributors */

import XCTest
import SwiftUI

@testable
import AirshipPreferenceCenter

class _PreferenceCenterThemeObjcTest: XCTestCase {

    func testConversion() {
        let theme = _PreferenceCenterThemeObjc()

        theme.contactSubscriptionGroup = _PreferenceCenterThemeObjc.ContactSubscriptionGroup()
        theme.contactSubscriptionGroup?.titleAppearance = _PreferenceCenterThemeObjc.TextAppearance()
        theme.contactSubscriptionGroup?.titleAppearance?.font = UIFont.boldSystemFont(ofSize: 10)
        theme.contactSubscriptionGroup?.titleAppearance?.color = UIColor.red

        theme.viewController = _PreferenceCenterThemeObjc.ViewController()
        theme.viewController?.navigationBar = _PreferenceCenterThemeObjc.NavigationBar()
        theme.viewController?.navigationBar?.title = "NEAT"

        theme.preferenceCenter = _PreferenceCenterThemeObjc.PreferenceCenter()
        theme.preferenceCenter?.retryMessage = "Retry it"

        let expected = PreferenceCenterTheme(
            viewController: PreferenceCenterTheme.ViewController(
                navigationBar: PreferenceCenterTheme.NavigationBar(
                    title: "NEAT"
                )
            ),
            preferenceCenter: PreferenceCenterTheme.PreferenceCenter(
                retryMessage: "Retry it"
            ),
            contactSubscriptionGroup: PreferenceCenterTheme.ContactSubscriptionGroup(
                titleAppearance: PreferenceCenterTheme.TextAppearance(
                    font: Font(UIFont.boldSystemFont(ofSize: 10)),
                    color: Color(UIColor.red))
            )
        )

        XCTAssertEqual(expected, theme.toPreferenceCenterTheme())
    }
}
