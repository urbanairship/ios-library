/* Copyright Airship and Contributors */

public import Foundation
@_spi(AirshipInternal) public import AirshipCore

nonisolated(unsafe) var debugModuleAIManager: (any AirshipAI.InternalManager)?

/// - Note: For internal use only. :nodoc:
@objc(UADebugSDKModule)
@_spi(AirshipInternal)
public final class DebugSDKModule: NSObject, AirshipSDKModule {

    public var actionsManifest: (any ActionsManifest)? = nil

    public let components: [any AirshipComponent]

    public static func load(_ args: AirshipModuleLoaderArgs) -> (any AirshipSDKModule)? {
        debugModuleAIManager = args.aiManager

        // Resume captures the user switched on in a previous session. The taps attach at
        // takeOff rather than when a screen appears, so a capture that is on records from
        // the first log line and the first evaluation — not from whenever someone next
        // opens the debug UI. Consent is still the only thing that decides whether
        // anything is written.
        resumeCaptures(aiManager: args.aiManager)

        let debugManager = DefaultAirshipDebugManager(
            config: args.config,
            analytics: args.analytics,
            remoteData: args.remoteData
        )
        return DebugSDKModule(debugManager)
    }

    private init(_ debugManager: any InternalAirshipDebugManager) {
        self.components = [DebugComponent(debugManager: debugManager)]
    }

    @MainActor
    private static func resumeCaptures(aiManager: (any AirshipAI.InternalManager)?) {
        let consent = AirshipDebugCaptureConsent.shared

        // The log tap is installed either way so that enabling capture later takes effect
        // immediately; `setRecording` is what gates the writes.
        AirshipDebugLogRecorder.shared.start()
        AirshipDebugLogRecorder.shared.setRecording(consent.isEnabled(.logs))

        if consent.isEnabled(.aiEvaluations), let aiManager {
            AirshipDebugAIEvaluationRecorder.shared.start(manager: aiManager)
        }
    }
}
