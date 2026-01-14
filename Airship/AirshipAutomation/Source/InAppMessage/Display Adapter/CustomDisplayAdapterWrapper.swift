/* Copyright Airship and Contributors */

import Foundation
import UIKit

#if canImport(AirshipCore)
import AirshipCore
#endif

/// Wraps a custom display adapter as a DisplayAdapter
final class CustomDisplayAdapterWrapper: DisplayAdapter {
    let adapter: any CustomDisplayAdapter

    @MainActor
    var isReady: Bool { return adapter.isReady }

    func waitForReady() async {
        await adapter.waitForReady()
    }

    init(
        adapter: any CustomDisplayAdapter
    ) {
        self.adapter = adapter
    }

    @MainActor
    func display(displayTarget: AirshipDisplayTarget, analytics: any InAppMessageAnalyticsProtocol) async throws -> DisplayResult {
        analytics.recordEvent(ThomasLayoutDisplayEvent(), layoutContext: nil)
        let scene = try displayTarget.sceneProvider()
        let timer = ActiveTimer()
        timer.start()
        let result = await self.adapter.display(scene: scene)
        timer.stop()

        switch(result) {
        case .buttonTap(let buttonInfo):
            analytics.recordEvent(
                ThomasLayoutResolutionEvent.buttonTap(
                    identifier: buttonInfo.identifier,
                    description: buttonInfo.label.text,
                    displayTime: timer.time
                ),
                layoutContext: nil
            )

            return buttonInfo.behavior == .cancel ? .cancel : .finished
        case .messageTap:
            analytics.recordEvent(
                ThomasLayoutResolutionEvent.messageTap(displayTime: timer.time),
                layoutContext: nil
            )
        case .userDismissed:
            analytics.recordEvent(
                ThomasLayoutResolutionEvent.userDismissed(displayTime: timer.time),
                layoutContext: nil
            )
        case .timedOut:
            analytics.recordEvent(
                ThomasLayoutResolutionEvent.timedOut(displayTime: timer.time),
                layoutContext: nil
            )
        }
        return .finished
    }
}
