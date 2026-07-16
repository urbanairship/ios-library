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
            var animation: Animation?
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
                case animation
                case swipeToDismiss = "swipe_to_dismiss"
                case shadow
            }
        }
        
        enum Animation: ThomasSerializable {
            case fade(FadeAnimation)
            case slide(SlideAnimation)
            
            private enum CodingKeys: String, CodingKey {
                case type = "type"
            }

            init(from decoder: any Decoder) throws {
                let container = try decoder.container(keyedBy: CodingKeys.self)
                let type = try container.decode(AnimationType.self, forKey: .type)

                self = switch type {
                case .fade: .fade(try FadeAnimation(from: decoder))
                case .slide: .slide(try SlideAnimation(from: decoder))
                }
            }

            func encode(to encoder: any Encoder) throws {
                switch self {
                case .fade(let info): try info.encode(to: encoder)
                case .slide(let info): try info.encode(to: encoder)
                }
            }
        }
        
        enum AnimationType: String, ThomasSerializable {
            case fade
            case slide
        }
        
        struct FadeAnimation: ThomasSerializable {
            var type: AnimationType = .fade
            var animateInSeconds: Double?
            var animateOutSeconds: Double?
            
            private enum CodingKeys: String, CodingKey {
                case type
                case animateInSeconds = "animate_in_seconds"
                case animateOutSeconds = "animate_out_seconds"
            }
        }
        
        struct SlideAnimation: ThomasSerializable {
            var type: AnimationType = .slide
            var animateInSeconds: Double?
            var animateOutSeconds: Double?
            
            private enum CodingKeys: String, CodingKey {
                case type
                case animateInSeconds = "animate_in_seconds"
                case animateOutSeconds = "animate_out_seconds"
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
            var animation: Animation?

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
                case animation
            }
        }
        
        enum Animation: ThomasSerializable {
            case fade(FadeAnimation)
            case slide(SlideAnimation)
            case explode(ExplodeAnimation)
            
            private enum CodingKeys: String, CodingKey {
                case type = "type"
            }

            init(from decoder: any Decoder) throws {
                let container = try decoder.container(keyedBy: CodingKeys.self)
                let type = try container.decode(AnimationType.self, forKey: .type)

                self = switch type {
                case .fade: .fade(try FadeAnimation(from: decoder))
                case .slide: .slide(try SlideAnimation(from: decoder))
                case .explode: .explode(try ExplodeAnimation(from: decoder))
                }
            }

            func encode(to encoder: any Encoder) throws {
                switch self {
                case .fade(let info): try info.encode(to: encoder)
                case .slide(let info): try info.encode(to: encoder)
                case .explode(let info): try info.encode(to: encoder)
                }
            }
        }
        
        enum AnimationType: String, ThomasSerializable {
            case fade
            case slide
            case explode
        }
        
        struct FadeAnimation: ThomasSerializable {
            var type: AnimationType = .fade
            var animateInSeconds: Double?
            var animateOutSeconds: Double?
            
            private enum CodingKeys: String, CodingKey {
                case type
                case animateInSeconds = "animate_in_seconds"
                case animateOutSeconds = "animate_out_seconds"
            }
        }
        
        struct SlideAnimation: ThomasSerializable {
            var type: AnimationType = .slide
            var animateInSeconds: Double?
            var animateOutSeconds: Double?
            var origin: ThomasEdgePosition
            
            private enum CodingKeys: String, CodingKey {
                case type
                case animateInSeconds = "animate_in_seconds"
                case animateOutSeconds = "animate_out_seconds"
                case origin
            }
        }
        
        struct ExplodeAnimation: ThomasSerializable {
            var type: AnimationType = .explode
            var animateInSeconds: Double?
            var animateOutSeconds: Double?
            var enter: ThomasCornerPosition
            var exit: ThomasCornerPosition
            
            private enum CodingKeys: String, CodingKey {
                case type
                case animateInSeconds = "animate_in_seconds"
                case animateOutSeconds = "animate_out_seconds"
                case enter
                case exit
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
