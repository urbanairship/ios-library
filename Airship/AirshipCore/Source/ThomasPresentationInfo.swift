/* Copyright Airship and Contributors */



enum ThomasPresentationInfo: ThomasSerializable {
    case banner(Banner)
    case modal(Modal)
    case embedded(Embedded)

    enum CodingKeys: String, CodingKey {
        case type
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(PresentationType.self, forKey: .type)

        self = switch type {
        case .banner: .banner(try Banner(from: decoder))
        case .modal: .modal(try Modal(from: decoder))
        case .embedded: .embedded(try Embedded(from: decoder))
        }
    }

    func encode(to encoder: any Encoder) throws {
        switch self {
        case .banner(let info): try info.encode(to: encoder)
        case .modal(let info): try info.encode(to: encoder)
        case .embedded(let info): try info.encode(to: encoder)
        }
    }

    enum PresentationType: String, ThomasSerializable {
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
        case safeArea = "sare_area"
    }

    struct iOS: ThomasSerializable {
        var keyboardAvoidance: KeyboardAvoidanceMethod?

        private enum CodingKeys: String, CodingKey {
            case keyboardAvoidance = "keyboard_avoidance"
        }
    }

    struct Banner: ThomasSerializable {
        let type: PresentationType = .banner
        var duration: Int?
        var placementSelectors: [PlacementSelector<Placement>]?
        var defaultPlacement: Placement
        var ios: iOS?

        private enum CodingKeys: String, CodingKey {
            case duration = "duration_milliseconds"
            case placementSelectors = "placement_selectors"
            case defaultPlacement = "default_placement"
            case type
        }

        enum Position: String, ThomasSerializable {
            case top
            case bottom
        }

        struct Placement: ThomasSerializable {
            var margin: ThomasMargin?
            var size: ThomasConstrainedSize
            var position: Position
            var ignoreSafeArea: Bool?
            var border: ThomasBorder?
            var backgroundColor: ThomasColor?
            var nubInfo: ThomasViewInfo.NubInfo?
            var cornerRadius: ThomasViewInfo.CornerRadiusInfo?

            private enum CodingKeys: String, CodingKey {
                case margin
                case size
                case position
                case ignoreSafeArea = "ignore_safe_area"
                case border
                case backgroundColor = "background_color"  
                case nubInfo = "nub"
                case cornerRadius = "corner_radius"
            }
        }
    }

    struct Modal: ThomasSerializable {
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
            }
        }
    }

    struct Embedded: ThomasSerializable {
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
