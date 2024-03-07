/* Copyright Airship and Contributors */

import Foundation
import SwiftUI
import AirshipCore

class CustomViewExampleHelper {

    static private func parseAdKeyword(json:AirshipJSON?)-> String? {
        guard let keywordDictionary = json?.unWrap() as? [String : String] else { return nil }

        return keywordDictionary["ad_type"]
    }
   
  

    static func registerWeatherView() {
        AirshipCustomViewManager.shared.register(name: "weather_custom_view") { json in
            AnyView(WeatherView())
        }
    }

    static func registerMapRouteView() {
        AirshipCustomViewManager.shared.register(name: "map_custom_view") { json in
            AnyView(MapRouteView())
        }
    }

    static func registerCameraView() {
        AirshipCustomViewManager.shared.register(name: "camera_custom_view") { json in
            AnyView(CameraView())
        }
    }

    static func registerBiometricLoginView() {
        AirshipCustomViewManager.shared.register(name: "biometric_login_custom_view") { json in
            /// Biometric login view has camera input as the background
            AnyView(BiometricLoginView())
        }
    }
}
