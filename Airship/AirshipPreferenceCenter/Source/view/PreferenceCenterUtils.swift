/* Copyright Airship and Contributors */

import Foundation
import SwiftUI

#if canImport(AirshipCore)
import AirshipCore
#endif

internal extension View {
    @ViewBuilder
    func backgroundWithCloseAction(onClose: (()->())?) -> some View {
        ZStack {
            Rectangle()
                .foregroundColor(Color.clear)
                .background(Color.airshipTappableClear.ignoresSafeArea(.all)).simultaneousGesture(TapGesture().onEnded { _ in
                if let onClose = onClose {
                    onClose()
                }
            }).zIndex(0)
            self.zIndex(1)
        }
    }
}

internal extension String {
    func countryFlag() -> String {
        return countryPhoneCodeToEmoji[self] ?? self
    }

    func replacingAsterisksWithBullets() -> String {
        return self.replacingOccurrences(of: "*", with: "●")
    }

    private func hideMidChars(_ value: String) -> String {
        return String(value.enumerated().map { index, char in
            return [0, value.count, value.count].contains(index) ? char : "*"
        })
    }

    func deletePrefix(_ prefix: String) -> String {
        guard self.hasPrefix(prefix) else { return self }
        return String(self.dropFirst(prefix.count))
    }
}

internal extension UIWindow {
    static func makeModalReadyWindow(
        scene: UIWindowScene
    ) -> UIWindow {
        let window: UIWindow = UIWindow(windowScene: scene)
        window.accessibilityViewIsModal = false
        window.alpha = 0
        window.makeKeyAndVisible()
        window.isUserInteractionEnabled = false

        return window
    }

    func animateIn() {
        self.windowLevel = .alert
        self.makeKeyAndVisible()
        self.isUserInteractionEnabled = true

        UIView.animate(
            withDuration: 0.3,
            animations: {
                self.alpha = 1
            },
            completion: { _ in
            }
        )
    }

    func animateOut() {
        UIView.animate(
            withDuration: 0.3,
            animations: {
                self.alpha = 0
            },
            completion: { _ in
                self.isHidden = true
                self.isUserInteractionEnabled = false
                self.removeFromSuperview()
            }
        )
    }
}

let countryPhoneCodeToEmoji: [String: String] = [
    "+1": "🇺🇸", // USA
    "+44": "🇬🇧", // United Kingdom
    "+49": "🇩🇪", // Germany
    "+33": "🇫🇷", // France
    "+81": "🇯🇵", // Japan
    "+39": "🇮🇹", // Italy
    "+91": "🇮🇳", // India
    "+86": "🇨🇳", // China
    "+7": "🇷🇺", // Russia
    "+55": "🇧🇷", // Brazil
    "+61": "🇦🇺", // Australia
    "+27": "🇿🇦", // South Africa
    "+82": "🇰🇷", // South Korea
    "+34": "🇪🇸", // Spain
    "+46": "🇸🇪", // Sweden
    "+48": "🇵🇱", // Poland
    "+47": "🇳🇴", // Norway
    "+31": "🇳🇱", // Netherlands
    "+51": "🇵🇪", // Peru
    "+52": "🇲🇽", // Mexico
    "+65": "🇸🇬", // Singapore
    "+64": "🇳🇿", // New Zealand
    "+90": "🇹🇷", // Turkey
    "+20": "🇪🇬", // Egypt
    "+60": "🇲🇾", // Malaysia
    "+63": "🇵🇭", // Philippines
    "+966": "🇸🇦", // Saudi Arabia
    "+971": "🇦🇪", // United Arab Emirates
    "+973": "🇧🇭", // Bahrain
    "+965": "🇰🇼", // Kuwait
    "+974": "🇶🇦", // Qatar
    "+93": "🇦🇫", // Afghanistan
    "+355": "🇦🇱", // Albania
    "+213": "🇩🇿", // Algeria
    "+1684": "🇦🇸", // American Samoa
    "+376": "🇦🇩", // Andorra
    "+244": "🇦🇴", // Angola
    "+1264": "🇦🇮", // Anguilla
    "+1268": "🇦🇬", // Antigua & Barbuda
    "+54": "🇦🇷", // Argentina
    "+374": "🇦🇲", // Armenia
    "+297": "🇦🇼", // Aruba
    "+43": "🇦🇹", // Austria
    "+994": "🇦🇿", // Azerbaijan
    "+1242": "🇧🇸", // Bahamas
    "+880": "🇧🇩", // Bangladesh
    "+1246": "🇧🇧", // Barbados
    "+375": "🇧🇾", // Belarus
    "+32": "🇧🇪", // Belgium
    "+501": "🇧🇿", // Belize
    "+229": "🇧🇯", // Benin
    "+1441": "🇧🇲", // Bermuda
    "+975": "🇧🇹", // Bhutan
    "+591": "🇧🇴", // Bolivia
    "+387": "🇧🇦", // Bosnia & Herzegovina
    "+267": "🇧🇼", // Botswana
    "+246": "🇮🇴", // British Indian Ocean Territory
    "+1284": "🇻🇬", // British Virgin Islands
    "+673": "🇧🇳", // Brunei
    "+359": "🇧🇬", // Bulgaria
    "+226": "🇧🇫", // Burkina Faso
    "+257": "🇧🇮", // Burundi
    "+855": "🇰🇭", // Cambodia
    "+237": "🇨🇲", // Cameroon
    "+238": "🇨🇻", // Cape Verde
    "+1345": "🇰🇾", // Cayman Islands
    "+236": "🇨🇫", // Central African Republic
    "+235": "🇹🇩", // Chad
    "+56": "🇨🇱", // Chile
    "+57": "🇨🇴", // Colombia
    "+269": "🇰🇲", // Comoros
    "+242": "🇨🇬", // Congo - Brazzaville
    "+243": "🇨🇩", // Congo - Kinshasa
    "+682": "🇨🇰", // Cook Islands
    "+506": "🇨🇷", // Costa Rica
    "+385": "🇭🇷", // Croatia
    "+53": "🇨🇺", // Cuba
    "+599": "🇨🇼", // Curaçao
    "+357": "🇨🇾", // Cyprus
    "+420": "🇨🇿", // Czechia
    "+45": "🇩🇰", // Denmark
    "+253": "🇩🇯", // Djibouti
    "+1767": "🇩🇲", // Dominica
    "+1809": "🇩🇴", // Dominican Republic
    "+593": "🇪🇨", // Ecuador
    "+503": "🇸🇻", // El Salvador
    "+240": "🇬🇶", // Equatorial Guinea
    "+291": "🇪🇷", // Eritrea
    "+372": "🇪🇪", // Estonia
    "+268": "🇸🇿", // Eswatini
    "+251": "🇪🇹", // Ethiopia
    "+500": "🇫🇰", // Falkland Islands
    "+298": "🇫🇴", // Faroe Islands
    "+679": "🇫🇯", // Fiji
    "+358": "🇫🇮", // Finland
    "+594": "🇬🇫", // French Guiana
    "+689": "🇵🇫", // French Polynesia
    "+241": "🇬🇦", // Gabon
    "+220": "🇬🇲", // Gambia
    "+995": "🇬🇪", // Georgia
    "+233": "🇬🇭", // Ghana
    "+350": "🇬🇮", // Gibraltar
    "+30": "🇬🇷", // Greece
    "+299": "🇬🇱", // Greenland
    "+1473": "🇬🇩", // Grenada
    "+1671": "🇬🇺", // Guam
    "+502": "🇬🇹", // Guatemala
    "+224": "🇬🇳", // Guinea
    "+245": "🇬🇼", // Guinea-Bissau
    "+592": "🇬🇾", // Guyana
    "+509": "🇭🇹", // Haiti
    "+504": "🇭🇳", // Honduras
    "+852": "🇭🇰", // Hong Kong SAR China
    "+36": "🇭🇺", // Hungary
    "+354": "🇮🇸", // Iceland
    "+62": "🇮🇩", // Indonesia
    "+98": "🇮🇷", // Iran
    "+964": "🇮🇶", // Iraq
    "+353": "🇮🇪", // Ireland
    "+972": "🇮🇱", // Israel
    "+225": "🇨🇮", // Ivory Coast
    "+1876": "🇯🇲", // Jamaica
    "+962": "🇯🇴", // Jordan
    "+254": "🇰🇪", // Kenya
    "+686": "🇰🇮", // Kiribati
    "+383": "🇽🇰", // Kosovo
    "+856": "🇱🇦", // Laos
    "+371": "🇱🇻", // Latvia
    "+961": "🇱🇧", // Lebanon
    "+266": "🇱🇸", // Lesotho
    "+231": "🇱🇷", // Liberia
    "+218": "🇱🇾", // Libya
    "+423": "🇱🇮", // Liechtenstein
    "+370": "🇱🇹", // Lithuania
    "+352": "🇱🇺", // Luxembourg
    "+853": "🇲🇴", // Macao SAR China
    "+261": "🇲🇬", // Madagascar
    "+265": "🇲🇼", // Malawi
    "+960": "🇲🇻", // Maldives
    "+223": "🇲🇱", // Mali
    "+356": "🇲🇹", // Malta
    "+692": "🇲🇭", // Marshall Islands
    "+596": "🇲🇶", // Martinique
    "+222": "🇲🇷", // Mauritania
    "+230": "🇲🇺", // Mauritius
    "+691": "🇫🇲", // Micronesia
    "+373": "🇲🇩", // Moldova
    "+377": "🇲🇨", // Monaco
    "+976": "🇲🇳", // Mongolia
    "+382": "🇲🇪", // Montenegro
    "+1664": "🇲🇸", // Montserrat
    "+212": "🇲🇦", // Morocco
    "+258": "🇲🇿", // Mozambique
    "+95": "🇲🇲", // Myanmar
    "+264": "🇳🇦", // Namibia
    "+674": "🇳🇷", // Nauru
    "+977": "🇳🇵", // Nepal
    "+687": "🇳🇨", // New Caledonia
    "+505": "🇳🇮", // Nicaragua
    "+227": "🇳🇪", // Niger
    "+234": "🇳🇬", // Nigeria
    "+683": "🇳🇺", // Niue
    "+672": "🇳🇫", // Norfolk Island
    "+1670": "🇲🇵", // Northern Mariana Islands
    "+389": "🇲🇰", // North Macedonia
    "+968": "🇴🇲", // Oman
    "+92": "🇵🇰", // Pakistan
    "+680": "🇵🇼", // Palau
    "+970": "🇵🇸", // Palestinian Territories
    "+507": "🇵🇦", // Panama
    "+675": "🇵🇬", // Papua New Guinea
    "+595": "🇵🇾", // Paraguay
    "+40": "🇷🇴", // Romania
    "+250": "🇷🇼", // Rwanda
    "+262": "🇷🇪", // Réunion
    "+1869": "🇰🇳", // St. Kitts & Nevis
    "+1758": "🇱🇨", // St. Lucia
    "+590": "🇲🇫", // St. Martin
    "+508": "🇵🇲", // St. Pierre & Miquelon
    "+1784": "🇻🇨", // St. Vincent & Grenadines
    "+685": "🇼🇸", // Samoa
    "+378": "🇸🇲", // San Marino
    "+239": "🇸🇹", // São Tomé & Príncipe
    "+221": "🇸🇳", // Senegal
    "+381": "🇷🇸", // Serbia
    "+248": "🇸🇨", // Seychelles
    "+232": "🇸🇱", // Sierra Leone
    "+1721": "🇸🇽", // Sint Maarten
    "+421": "🇸🇰", // Slovakia
    "+386": "🇸🇮", // Slovenia
    "+677": "🇸🇧", // Solomon Islands
    "+252": "🇸🇴", // Somalia
    "+211": "🇸🇸", // South Sudan
    "+94": "🇱🇰", // Sri Lanka
    "+249": "🇸🇩", // Sudan
    "+597": "🇸🇷", // Suriname
    "+41": "🇨🇭", // Switzerland
    "+963": "🇸🇾", // Syria
    "+886": "🇹🇼", // Taiwan
    "+992": "🇹🇯", // Tajikistan
    "+255": "🇹🇿", // Tanzania
    "+66": "🇹🇭", // Thailand
    "+670": "🇹🇱", // Timor-Leste
    "+228": "🇹🇬", // Togo
    "+690": "🇹🇰", // Tokelau
    "+676": "🇹🇴", // Tonga
    "+1868": "🇹🇹", // Trinidad & Tobago
    "+216": "🇹🇳", // Tunisia
    "+993": "🇹🇲", // Turkmenistan
    "+1649": "🇹🇨", // Turks & Caicos Islands
    "+688": "🇹🇻", // Tuvalu
    "+256": "🇺🇬", // Uganda
    "+380": "🇺🇦", // Ukraine
    "+598": "🇺🇾", // Uruguay
    "+998": "🇺🇿", // Uzbekistan
    "+678": "🇻🇺", // Vanuatu
    "+58": "🇻🇪", // Venezuela
    "+84": "🇻🇳", // Vietnam
    "+681": "🇼🇫", // Wallis & Futuna
    "+967": "🇾🇪", // Yemen
    "+260": "🇿🇲", // Zambia
    "++263": "🇿🇼"  // Zimbabwe
]
