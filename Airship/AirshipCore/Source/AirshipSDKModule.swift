//
//  AirshipSDKModule.swift
//  Airship
//
//  Created by Ryan Lepinski on 6/7/23.
//  Copyright © 2023 Urban Airship. All rights reserved.
//

import Foundation


public protocol AirshipSDKModule: NSObject {
    var actionsManifest: ActionsManifest? { get }
    var components: [AirshipComponent] { get }

    @MainActor
    static func load(dependencies: [String: Any]) -> AirshipSDKModule?
}
