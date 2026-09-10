/* Copyright Airship and Contributors */

import Foundation

/// - Note: For internal use only. :nodoc:
@_spi(AirshipInternal)
@frozen
public enum ThomasPresentationInfo: ThomasSerializable {
    case banner(Banner)
    case modal(Modal)
    case embedded(Embedded)

    enum CodingKeys: String, CodingKey {
        case type
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(PresentationType.self, forKey: .type)

        self = switch type {
        case .banner: .banner(try Banner(from: decoder))
        case .modal: .modal(try Modal(from: decoder))
        case .embedded: .embedded(try Embedded(from: decoder))
        }
    }

    public func encode(to encoder: any Encoder) throws {
        switch self {
        case .banner(let info): try info.encode(to: encoder)
        case .modal(let info): try info.encode(to: encoder)
        case .embedded(let info): try info.encode(to: encoder)
        }
    }

    public enum PresentationType: String, ThomasSerializable {
        case modal
        case banner
        case embedded
    }

    struct Device: ThomasSerializable {
        let orientationLock: ThomasOrientation?
        private enum CodingKeys: String, CodingKey {
            case orientationLock = "lock_orientation"
        }
    }

    /// Keyboard avoidance methods
    enum KeyboardAvoidanceMethod: String, ThomasSerializable {
        /// Slide keyboard over the top
        case overTheTop = "over_the_top"
        /// Treat it as safe area
        case safeArea = "safe_area"
    }

    struct iOS: ThomasSerializable {
        var keyboardAvoidance: KeyboardAvoidanceMethod?

        private enum CodingKeys: String, CodingKey {
            case keyboardAvoidance = "keyboard_avoidance"
        }
    }

    public struct Banner: ThomasSerializable {
        let type: PresentationType = .banner
        var durationSeconds: TimeInterval?
        var placementSelectors: [PlacementSelector<Placement>]?
        var defaultPlacement: Placement
        var ios: iOS?

        private enum CodingKeys: String, CodingKey {
            case durationSeconds = "duration_seconds"
            case placementSelectors = "placement_selectors"
            case defaultPlacement = "default_placement"
            case type
            case ios
        }

        public init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)

            self.durationSeconds = try container.decodeIfPresent(TimeInterval.self, forKey: .durationSeconds)
            self.placementSelectors = try container.decodeIfPresent(
                [PlacementSelector<Placement>].self,
                forKey: .placementSelectors
            )
            self.defaultPlacement = try container.decode(Placement.self, forKey: .defaultPlacement)
            self.ios = try container.decodeIfPresent(iOS.self, forKey: .ios)
        }

        public func encode(to encoder: any Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(type, forKey: .type)
            try container.encodeIfPresent(durationSeconds, forKey: .durationSeconds)
            try container.encodeIfPresent(placementSelectors, forKey: .placementSelectors)
            try container.encode(defaultPlacement, forKey: .defaultPlacement)
            try container.encodeIfPresent(ios, forKey: .ios)
        }

        struct Placement: ThomasSerializable {
            var margin: ThomasMargin?
            var size: ThomasConstrainedSize
            var position: ThomasEdgePosition
            var ignoreSafeArea: Bool?
            var border: ThomasBorder?
            var backgroundColor: ThomasColor?
            // Optional for legacy payloads; nil renders as slide
            var transition: Transition?
            var swipeToDismiss: Bool?
            var shadow: ThomasShadow?

            /// Swipe-to-dismiss defaults to enabled when unset to preserve
            /// legacy banner behavior.
            var isSwipeToDismissEnabled: Bool { swipeToDismiss ?? true }

            private enum CodingKeys: String, CodingKey {
                case margin
                case size
                case position
                case ignoreSafeArea = "ignore_safe_area"
                case border
                case backgroundColor = "background_color"
                case transition
                case swipeToDismiss = "swipe_to_dismiss"
                case shadow
            }
        }

        /// A banner's own enter and exit transition.
        struct Transition: ThomasSerializable {
            var enter: Effect
            var exit: Effect

            private enum CodingKeys: String, CodingKey {
                case enter = "in"
                case exit = "out"
            }
        }

        /// What a banner draws for one direction of its transition. Same pattern as
        /// `Modal.Effect`, but slide has no edge of its own -- it's always the banner's own
        /// placement edge, so there's no sensible independent value to give it.
        enum Effect: ThomasSerializable {
            case fade(FadeEffect)
            case slide(SlideEffect)

            private enum CodingKeys: String, CodingKey {
                case type = "type"
            }

            init(from decoder: any Decoder) throws {
                let container = try decoder.container(keyedBy: CodingKeys.self)
                let type = try container.decode(EffectType.self, forKey: .type)

                self = switch type {
                case .fade: .fade(try FadeEffect(from: decoder))
                case .slide: .slide(try SlideEffect(from: decoder))
                }
            }

            func encode(to encoder: any Encoder) throws {
                switch self {
                case .fade(let info): try info.encode(to: encoder)
                case .slide(let info): try info.encode(to: encoder)
                }
            }

            var durationMilliseconds: Int? {
                switch self {
                case .fade(let effect): effect.durationMilliseconds
                case .slide(let effect): effect.durationMilliseconds
                }
            }
        }

        enum EffectType: String, ThomasSerializable {
            case fade
            case slide
        }

        struct FadeEffect: ThomasSerializable {
            var type: EffectType = .fade
            var durationMilliseconds: Int?

            private enum CodingKeys: String, CodingKey {
                case type
                case durationMilliseconds = "duration_milliseconds"
            }
        }

        struct SlideEffect: ThomasSerializable {
            var type: EffectType = .slide
            var durationMilliseconds: Int?

            private enum CodingKeys: String, CodingKey {
                case type
                case durationMilliseconds = "duration_milliseconds"
            }
        }
    }

    public struct Modal: ThomasSerializable {
        let type: PresentationType = .modal
        var placementSelectors: [PlacementSelector<Placement>]?
        var defaultPlacement: Placement
        var dismissOnTouchOutside: Bool?
        var device: Device?
        var ios: iOS?

        private enum CodingKeys: String, CodingKey {
            case placementSelectors = "placement_selectors"
            case defaultPlacement = "default_placement"
            case dismissOnTouchOutside = "dismiss_on_touch_outside"
            case device
            case type
            case ios
        }

        struct Placement: ThomasSerializable {
            var margin: ThomasMargin?
            var size: ThomasConstrainedSize
            var position: ThomasPosition?
            var shade: ThomasColor?
            var ignoreSafeArea: Bool?
            var device: Device?
            var border: ThomasBorder?
            var backgroundColor: ThomasColor?
            var shadow: ThomasShadow?
            var transition: Transition?

            private enum CodingKeys: String, CodingKey {
                case margin
                case size
                case position
                case shade = "shade_color"
                case ignoreSafeArea = "ignore_safe_area"
                case device
                case border
                case backgroundColor = "background_color"
                case shadow
                case transition
            }
        }

        /// A modal's own enter and exit transition -- a plain transition and one whose entrance
        /// and exit are different effects entirely (explode in, fade out) are both just this,
        /// played twice, rather than a symmetric case with a separate "asymmetric" one bolted on
        /// beside it.
        struct Transition: ThomasSerializable {
            var enter: Effect
            var exit: Effect

            private enum CodingKeys: String, CodingKey {
                case enter = "in"
                case exit = "out"
            }

            /// Whether both directions are a plain fade, with no shape of their own to give a
            /// transition anything to move -- the shade can then animate as one unit with the
            /// content instead of needing its own, separate transition.
            var isPlainFade: Bool {
                if case .fade = enter, case .fade = exit { return true }
                return false
            }
        }

        /// What a modal draws for one direction of its transition. An effect only ever plays its
        /// own direction, so its own `durationMilliseconds` lives here rather than on a wrapper as
        /// an `animateInSeconds`/`animateOutSeconds` pair that `enter`/`exit` would otherwise have
        /// to be cross-referenced against by name.
        enum Effect: ThomasSerializable {
            case fade(FadeEffect)
            case slide(SlideEffect)
            case explode(ExplodeEffect)

            private enum CodingKeys: String, CodingKey {
                case type = "type"
            }

            init(from decoder: any Decoder) throws {
                let container = try decoder.container(keyedBy: CodingKeys.self)
                let type = try container.decode(EffectType.self, forKey: .type)

                self = switch type {
                case .fade: .fade(try FadeEffect(from: decoder))
                case .slide: .slide(try SlideEffect(from: decoder))
                case .explode: .explode(try ExplodeEffect(from: decoder))
                }
            }

            func encode(to encoder: any Encoder) throws {
                switch self {
                case .fade(let info): try info.encode(to: encoder)
                case .slide(let info): try info.encode(to: encoder)
                case .explode(let info): try info.encode(to: encoder)
                }
            }

            var durationMilliseconds: Int? {
                switch self {
                case .fade(let effect): effect.durationMilliseconds
                case .slide(let effect): effect.durationMilliseconds
                case .explode(let effect): effect.durationMilliseconds
                }
            }
        }

        enum EffectType: String, ThomasSerializable {
            case fade
            case slide
            case explode
        }

        struct FadeEffect: ThomasSerializable {
            var type: EffectType = .fade
            var durationMilliseconds: Int?

            private enum CodingKeys: String, CodingKey {
                case type
                case durationMilliseconds = "duration_milliseconds"
            }
        }

        struct SlideEffect: ThomasSerializable {
            var type: EffectType = .slide
            var durationMilliseconds: Int?
            var edge: ThomasEdgePosition

            private enum CodingKeys: String, CodingKey {
                case type
                case durationMilliseconds = "duration_milliseconds"
                case edge
            }
        }

        struct ExplodeEffect: ThomasSerializable {
            var type: EffectType = .explode
            var durationMilliseconds: Int?
            var corner: ThomasCornerPosition

            private enum CodingKeys: String, CodingKey {
                case type
                case durationMilliseconds = "duration_milliseconds"
                case corner
            }
        }
    }

    public struct Embedded: ThomasSerializable {
        let type: PresentationType = .embedded
        var placementSelectors: [PlacementSelector<Placement>]?
        var defaultPlacement: Placement
        var embeddedID: String

        private enum CodingKeys: String, CodingKey {
            case defaultPlacement = "default_placement"
            case placementSelectors = "placement_selectors"
            case embeddedID = "embedded_id"
            case type
        }

        struct Placement: ThomasSerializable {
            let margin: ThomasMargin?
            let size: ThomasConstrainedSize
            let border: ThomasBorder?
            let backgroundColor: ThomasColor?

            private enum CodingKeys: String, CodingKey {
                case margin
                case size
                case border
                case backgroundColor = "background_color"
            }
        }
    }

    struct PlacementSelector<Placement: ThomasSerializable>: ThomasSerializable {
        var placement: Placement
        var windowSize: ThomasWindowSize?
        var orientation: ThomasOrientation?

        private enum CodingKeys: String, CodingKey {
            case placement
            case windowSize = "window_size"
            case orientation
        }
    }
}
