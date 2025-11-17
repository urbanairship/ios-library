/* Copyright Airship and Contributors */
#if !os(macOS)

import Foundation
import UIKit

#if canImport(AirshipCore)
import AirshipCore
#endif

protocol InAppMessageSceneManagerProtocol: AnyObject, Sendable {
    @MainActor
    var delegate: (any InAppMessageSceneDelegate)? { get set }

    @MainActor
    func scene(forMessage: InAppMessage) throws -> any WindowSceneHolder
}

final class InAppMessageSceneManager: InAppMessageSceneManagerProtocol, Sendable {

    @MainActor
    weak var delegate: (any InAppMessageSceneDelegate)?

    private let sceneManger: any AirshipSceneManagerProtocol

    init(sceneManger: any AirshipSceneManagerProtocol) {
        self.sceneManger = sceneManger
    }

    @MainActor
    func scene(forMessage message: InAppMessage) throws -> any WindowSceneHolder {
        let scene = try self.delegate?.sceneForMessage(message) ?? sceneManger.lastActiveScene
        return DefaultWindowSceneHolder(scene: scene)
    }
}

protocol WindowSceneHolder: Sendable {
    @MainActor
    var scene: UIWindowScene { get }
}

@MainActor
struct DefaultWindowSceneHolder: WindowSceneHolder {
    var scene: UIWindowScene
}

#endif
