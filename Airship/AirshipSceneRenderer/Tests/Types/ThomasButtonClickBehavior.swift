/* Copyright Airship and Contributors */

import Foundation
import Testing

@testable import AirshipBasement
@testable @_spi(AirshipInternal) import AirshipSceneRenderer

@Suite(.timeLimit(.minutes(1)))
struct ThomasButtonClickBehaviorParsingTest {
    
    static let allBehaviors: [ThomasButtonClickBehavior] = [
        .dismiss, .cancel,
        .pagerNext, .pagerPrevious, .pagerNextOrDismiss, .pagerNextOrFirst,
        .pagerPause, .pagerResume, .pagerPauseToggle,
        .videoPlay, .videoPause, .videoTogglePlay,
        .videoMute, .videoUnmute, .videoToggleMute,
        .formSubmit, .formValidate,
        .asyncViewRetry,
    ]


    private let decoder = JSONDecoder()

    @Test("Decode all raw values", arguments: [
        ("dismiss",           ThomasButtonClickBehavior.dismiss),
        ("cancel",            .cancel),
        ("pager_next",        .pagerNext),
        ("pager_previous",    .pagerPrevious),
        ("pager_next_or_dismiss", .pagerNextOrDismiss),
        ("pager_next_or_first",   .pagerNextOrFirst),
        ("form_submit",       .formSubmit),
        ("form_validate",     .formValidate),
        ("pager_pause",       .pagerPause),
        ("pager_resume",      .pagerResume),
        ("async_view_retry",  .asyncViewRetry),
        ("pager_toggle_pause",.pagerPauseToggle),
        ("video_play",        .videoPlay),
        ("video_pause",       .videoPause),
        ("video_toggle_play", .videoTogglePlay),
        ("video_mute",        .videoMute),
        ("video_unmute",      .videoUnmute),
        ("video_toggle_mute", .videoToggleMute),
    ] as [(String, ThomasButtonClickBehavior)])
    func decodeRawValue(raw: String, expected: ThomasButtonClickBehavior) throws {
        let data = Data("\"\(raw)\"".utf8)
        let decoded = try decoder.decode(ThomasButtonClickBehavior.self, from: data)
        #expect(decoded == expected)
    }

    @Test
    func decodeUnknownRawValueThrows() {
        let data = Data("\"unknown_behavior\"".utf8)
        #expect(throws: (any Error).self) {
            try decoder.decode(ThomasButtonClickBehavior.self, from: data)
        }
    }

    @Test
    func encodeRoundTrips() throws {
        let encoder = JSONEncoder()
        for behavior in Self.allBehaviors {
            let encoded = try encoder.encode(behavior)
            let decoded = try decoder.decode(ThomasButtonClickBehavior.self, from: encoded)
            #expect(decoded == behavior, "Round-trip failed for \(behavior)")
        }
    }
}
