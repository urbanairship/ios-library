/* Copyright Airship and Contributors */

import SwiftUI

extension ThomasViewInfo.Pager {
    var isDefaultSwipeEnabled: Bool {
        return self.properties.disableSwipe != true && self.properties.items.count > 1
    }

    func retrieveGestures<T: ThomasViewInfo.Pager.Gesture.Info>(type: T.Type) -> [T] {
        guard let gestures = self.properties.gestures else {
            return []
        }

        return gestures.compactMap { gesture in
            switch gesture {
            case .tapGesture(let model):
                return model as? T
            case .swipeGesture(let model):
                return model as? T
            case .holdGesture(let model):
                return model as? T
            }
        }
    }

    func containsGestures(_ types: [ThomasViewInfo.Pager.Gesture.GestureType]) -> Bool {
        guard let gestures = self.properties.gestures else {
            return false
        }

        return gestures.contains(where: { gesture in
            switch(gesture) {
            case .swipeGesture(let gesture): return types.contains(gesture.type)
            case .tapGesture(let gesture): return types.contains(gesture.type)
            case .holdGesture(let gesture): return types.contains(gesture.type)
            }
        })
    }
}

extension Array where Element == ThomasAutomatedAction {
    var earliestNavigationAction: ThomasAutomatedAction? {
        return self.first {
            return $0.behaviors?.filter {
                return switch($0) {
                case .dismiss: true
                case .cancel: true
                case .pagerNext: true
                case .pagerPrevious: true
                case .pagerNextOrDismiss: true
                case .pagerNextOrFirst: true
                case .formValidate: false
                case .formSubmit: false
                case .pagerPause: false
                case .pagerResume: false
                case .pagerPauseToggle: false
                case .asyncViewRetry: false
                case .videoPlay: false
                case .videoPause: false
                case .videoTogglePlay: false
                case .videoMute: false
                case .videoUnmute: false
                case .videoToggleMute: false
                }
            }.isEmpty == false
        }
    }
}

/// Collects the frames of interactive elements (currently buttons) within a pager so the
/// pager can skip firing region-based tap gestures when a tap lands on one of them.
///
/// The pager attaches its region tap detector to the whole container with a
/// `simultaneousGesture`, which by design also recognizes taps that land on child buttons.
/// Rather than change that gesture arbitration (which would risk the pager's swipe/hold
/// gestures and scrolling), interactive elements report their frames here and the pager
/// filters them out in its tap handler.
///
/// Frames are reported in the named coordinate space established by the pager and bubbled
/// up via this preference. Reporting is gated by ``EnvironmentValues/pagerTapExclusionSpace``:
/// it is only set by a pager that has tap gestures, so buttons elsewhere add no overhead.
///
/// Each frame is tagged with the coordinate space it was measured in. Preferences bubble
/// past the nearest pager to any enclosing pagers, so with nested pagers each one must keep
/// only the frames measured in its own space — an inner pager's frames are meaningless in
/// the outer pager's coordinates.
struct PagerGestureExclusionFrame: Equatable, Sendable {
    let space: String
    let frame: CGRect
}

struct PagerGestureExclusionFramesKey: PreferenceKey {
    static let defaultValue: [PagerGestureExclusionFrame] = []
    static func reduce(value: inout [PagerGestureExclusionFrame], nextValue: () -> [PagerGestureExclusionFrame]) {
        value.append(contentsOf: nextValue())
    }
}

private struct PagerGestureExclusionReporter: ViewModifier {
    @Environment(\.pagerTapExclusionSpace) private var exclusionSpace
    @Environment(\.isEnabled) private var isEnabled

    func body(content: Content) -> some View {
        // Only report when inside a pager that opted in AND this element is enabled. A
        // disabled element (e.g. a submit button greyed out until the form is valid, or a
        // pager-next button on the last page) does not consume the tap, so the region
        // gesture should still fire on it.
        if let exclusionSpace, isEnabled {
            content.background(
                GeometryReader { proxy in
                    Color.clear.preference(
                        key: PagerGestureExclusionFramesKey.self,
                        value: [
                            PagerGestureExclusionFrame(
                                space: exclusionSpace,
                                frame: proxy.frame(in: .named(exclusionSpace))
                            )
                        ]
                    )
                }
            )
        } else {
            content
        }
    }
}

extension View {
    /// Reports this view's frame as a region that should suppress pager region tap gestures,
    /// but only when inside a pager that opted in via `pagerTapExclusionSpace`.
    func reportPagerGestureExclusion() -> some View {
        self.modifier(PagerGestureExclusionReporter())
    }

#if !os(tvOS)
    @ViewBuilder
    func addPagerTapGesture(onTouch: @escaping (Bool) -> Void, onTap: @escaping (CGPoint) -> Void) -> some View {
        self.onTouch { isPressed in
            onTouch(isPressed)
        }
        .simultaneousGesture(
            SpatialTapGesture()
                .onEnded { event in
                    onTap(event.location)
                }
            )
    }
#endif
}
