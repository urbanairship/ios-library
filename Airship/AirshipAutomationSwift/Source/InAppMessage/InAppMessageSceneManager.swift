/* Copyright Airship and Contributors */

import Foundation

import UIKit
#if canImport(AirshipCore)
import AirshipCore
#endif

protocol InAppMessageSceneManagerProtocol: AnyObject, Sendable {
    @MainActor
    var delegate: InAppMessageSceneDelegate? { get set }

    @MainActor
    func scene(forMessage: InAppMessage) throws -> WindowSceneHolder
}

final class InAppMessageSceneManager: InAppMessageSceneManagerProtocol, @unchecked Sendable {

    @MainActor
    weak var delegate: InAppMessageSceneDelegate?

    private let sceneManger: AirshipSceneManagerProtocol

    init(sceneManger: AirshipSceneManagerProtocol) {
        self.sceneManger = sceneManger
    }

    @MainActor
    func scene(forMessage message: InAppMessage) throws -> WindowSceneHolder {
        let scene = try self.delegate?.sceneForMessage(message) ?? sceneManger.lastActiveScene
        return DefaultWindowSceneHolder(scene: scene)
    }
}

protocol WindowSceneHolder: Sendable {
    @MainActor
    var scene: UIWindowScene { get }
}

@MainActor
fileprivate struct DefaultWindowSceneHolder: WindowSceneHolder {
    var scene: UIWindowScene
}
