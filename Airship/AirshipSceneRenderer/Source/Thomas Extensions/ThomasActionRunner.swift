/* Copyright Airship and Contributors */

import Foundation
import SwiftUI
public import AirshipBasement

/// Thomas action runner
/// - Note: For internal use only. :nodoc:
@_spi(AirshipInternal)
public protocol ThomasActionRunner: Sendable {
    /// Runs the given actions payload (button taps, gestures, automated page actions).
    @MainActor
    func runAsync(actions: AirshipJSON, layoutContext: ThomasLayoutContext)

    /// Runs a single named action (e.g. triggered from a web view's JS bridge) and returns its result.
    @MainActor
    func run(actionName: String, arguments: ActionArguments, layoutContext: ThomasLayoutContext) async -> ActionResult
}
