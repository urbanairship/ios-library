/* Copyright Airship and Contributors */

import Combine
import Foundation
import UIKit
import SwiftUI

#if canImport(AirshipCore)
import AirshipCore
#endif

@MainActor
class InAppMessageEnvironment: ObservableObject {
    private let delegate: InAppMessageViewDelegate

    let imageLoader: AirshipImageLoader
    let nativeBridgeExtension: NativeBridgeExtensionDelegate?
    let actionRunner: InAppActionRunner?

    @Published var isDismissed = false

    @MainActor
    init(
        delegate: InAppMessageViewDelegate,
        extensions: InAppMessageExtensions? = nil
    ) {
        self.delegate = delegate

        self.imageLoader = AirshipImageLoader(imageProvider: extensions?.imageProvider)

        self.nativeBridgeExtension = extensions?.nativeBridgeExtension
        self.actionRunner = extensions?.actionRunner
    }

    private func tryDismiss(callback: @escaping () -> Void) {
        if !self.isDismissed {
            withAnimation {
                self.isDismissed = true
            }
            callback()
        }
    }

    @MainActor
    func onAppear() {
        self.delegate.onAppear()
    }

    /// Called when a button dismisses the in-app message
    /// - Parameters:
    ///     - buttonInfo: The button info on the dismissing button.
    @MainActor
    func onButtonDismissed(buttonInfo: InAppMessageButtonInfo) {
        tryDismiss {
            self.delegate.onButtonDismissed(buttonInfo: buttonInfo)
        }
    }
    
    func runActions(actions: AirshipJSON?) {
        guard let actions = actions else { return }
        
        Task {
            await ActionRunner.run(actionsPayload: actions, situation: .automation, metadata: [:])
        }
    }


    @MainActor
    func runActions(_ actions: AirshipJSON?) {
        guard let actions = actions else { return }

        guard let runner = actionRunner else {
            Task {
                await ActionRunner.run(
                    actionsPayload: actions,
                    situation: .automation,
                    metadata: [:]
                )
            }

            return
        }

        runner.runAsync(actions: actions)
    }

    @MainActor
    func runAction(_ actionName: String, arguments: ActionArguments) async -> ActionResult {
        guard let runner = actionRunner else {
            return await ActionRunner.run(actionName: actionName, arguments: arguments)
        }

        return await runner.run(
            actionName: actionName,
            arguments: arguments
        )
    }

    /// Called when a message dismisses after the set timeout period
    @MainActor
    func onTimedOut() {
        tryDismiss {
            self.delegate.onTimedOut()
        }
    }

    /// Called when a message dismisses with the close button or banner drawer handle
    @MainActor
    func onUserDismissed() {
        tryDismiss {
           self.delegate.onUserDismissed()
        }
    }

    /// Called when a message is dismissed via a tap to the message body
    @MainActor
    func onMessageTapDismissed() {
        tryDismiss {
            self.delegate.onMessageTapDismissed()
        }
    }
}
