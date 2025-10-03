/* Copyright Airship and Contributors */

import SwiftUI
import Foundation

indirect enum ThomasViewInfo: ThomasSerializable {
    case container(Container)
    case linearLayout(LinearLayout)
    #if !os(tvOS) && !os(watchOS)
    case webView(WebView)
    #endif
    case customView(CustomView)
    case scrollLayout(ScrollLayout)
    case media(Media)
    case label(Label)
    case labelButton(LabelButton)
    case imageButton(ImageButton)
    case emptyView(EmptyView)
    case pager(Pager)
    case pagerIndicator(PagerIndicator)
    case storyIndicator(StoryIndicator)
    case pagerController(PagerController)
    case formController(FormController)
    case checkbox(Checkbox)
    case checkboxController(CheckboxController)
    case radioInput(RadioInput)
    case radioInputController(RadioInputController)
    case textInput(TextInput)
    case score(Score)
    case npsController(NPSController)
    case toggle(Toggle)
    case stateController(StateController)
    case buttonLayout(ButtonLayout)
    case basicToggleLayout(BasicToggleLayout)
    case checkboxToggleLayout(CheckboxToggleLayout)
    case radioInputToggleLayout(RadioInputToggleLayout)
    case iconView(IconView)
    case scoreController(ScoreController)
    case scoreToggleLayout(ScoreToggleLayout)

    enum ViewType: String, Codable {
        case container
        case linearLayout = "linear_layout"
        case webView = "web_view"
        case customView = "custom_view"
        case scrollLayout = "scroll_layout"
        case media
        case label
        case labelButton = "label_button"
        case imageButton = "image_button"
        case buttonLayout = "button_layout"
        case emptyView = "empty_view"
        case pager
        case pagerIndicator = "pager_indicator"
        case storyIndicator = "story_indicator"
        case pagerController = "pager_controller"
        case formController = "form_controller"
        case checkbox
        case checkboxController = "checkbox_controller"
        case radioInput = "radio_input"
        case radioInputController = "radio_input_controller"
        case textInput = "text_input"
        case score
        case npsController = "nps_form_controller"
        case toggle
        case basicToggleLayout = "basic_toggle_layout"
        case checkboxToggleLayout = "checkbox_toggle_layout"
        case radioInputToggleLayout = "radio_input_toggle_layout"
        case stateController = "state_controller"
        case iconView = "icon_view"
        case scoreController = "score_controller"
        case scoreToggleLayout = "score_toggle_layout"

    }

    protocol BaseInfo: ThomasSerializable {
        var commonProperties: CommonViewProperties { get }
        var commonOverrides: CommonViewOverrides? { get }
    }

    private enum CodingKeys: String, CodingKey {
        case type
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(ViewType.self, forKey: .type)

        self = switch type {
        case .container: .container(try Container(from: decoder))
        case .linearLayout: .linearLayout(try LinearLayout(from: decoder))

        case .webView:
#if os(tvOS) || os(watchOS)
            throw AirshipErrors.error(
                "Webview not available on tvOS and watchOS"
            )
#else
            .webView(try WebView(from: decoder))
#endif

        case .scrollLayout: .scrollLayout(try ScrollLayout(from: decoder))
        case .media: .media(try Media(from: decoder))
        case .label: .label(try Label(from: decoder))
        case .labelButton: .labelButton(try LabelButton(from: decoder))
        case .imageButton: .imageButton(try ImageButton(from: decoder))
        case .emptyView: .emptyView(try EmptyView(from: decoder))
        case .pager: .pager(try Pager(from: decoder))
        case .pagerIndicator: .pagerIndicator(try PagerIndicator(from: decoder))
        case .storyIndicator: .storyIndicator(try StoryIndicator(from: decoder))
        case .pagerController: .pagerController(try PagerController(from: decoder))
        case .formController: .formController(try FormController(from: decoder))
        case .checkbox: .checkbox(try Checkbox(from: decoder))
        case .checkboxController: .checkboxController(try CheckboxController(from: decoder))
        case .radioInput: .radioInput(try RadioInput(from: decoder))
        case .radioInputController: .radioInputController(try RadioInputController(from: decoder))
        case .textInput: .textInput(try TextInput(from: decoder))
        case .score: .score(try Score(from: decoder))
        case .npsController: .npsController(try NPSController(from: decoder))
        case .toggle: .toggle(try Toggle(from: decoder))
        case .stateController: .stateController(try StateController(from: decoder))
        case .customView: .customView(try CustomView(from: decoder))
        case .buttonLayout: .buttonLayout(try ButtonLayout(from: decoder))
        case .basicToggleLayout: .basicToggleLayout(try BasicToggleLayout(from: decoder))
        case .checkboxToggleLayout: .checkboxToggleLayout(try CheckboxToggleLayout(from: decoder))
        case .radioInputToggleLayout: .radioInputToggleLayout(try RadioInputToggleLayout(from: decoder))
        case .iconView: .iconView(try IconView(from: decoder))
        case .scoreController: .scoreController(try ScoreController(from: decoder))
        case .scoreToggleLayout: .scoreToggleLayout(try ScoreToggleLayout(from: decoder))
        }
    }

    func encode(to encoder: any Encoder) throws {
        switch self {
        case .container(let info): try info.encode(to: encoder)
        case .linearLayout(let info): try info.encode(to: encoder)
        #if !os(tvOS) && !os(watchOS)
        case .webView(let info): try info.encode(to: encoder)
        #endif
        case .customView(let info): try info.encode(to: encoder)
        case .scrollLayout(let info): try info.encode(to: encoder)
        case .media(let info): try info.encode(to: encoder)
        case .label(let info): try info.encode(to: encoder)
        case .labelButton(let info): try info.encode(to: encoder)
        case .imageButton(let info): try info.encode(to: encoder)
        case .emptyView(let info): try info.encode(to: encoder)
        case .pager(let info): try info.encode(to: encoder)
        case .pagerIndicator(let info): try info.encode(to: encoder)
        case .storyIndicator(let info): try info.encode(to: encoder)
        case .pagerController(let info): try info.encode(to: encoder)
        case .formController(let info): try info.encode(to: encoder)
        case .checkbox(let info): try info.encode(to: encoder)
        case .checkboxController(let info): try info.encode(to: encoder)
        case .radioInput(let info): try info.encode(to: encoder)
        case .radioInputController(let info): try info.encode(to: encoder)
        case .textInput(let info): try info.encode(to: encoder)
        case .score(let info): try info.encode(to: encoder)
        case .npsController(let info): try info.encode(to: encoder)
        case .toggle(let info): try info.encode(to: encoder)
        case .stateController(let info): try info.encode(to: encoder)
        case .buttonLayout(let info): try info.encode(to: encoder)
        case .basicToggleLayout(let info): try info.encode(to: encoder)
        case .checkboxToggleLayout(let info): try info.encode(to: encoder)
        case .radioInputToggleLayout(let info): try info.encode(to: encoder)
        case .iconView(let info): try info.encode(to: encoder)
        case .scoreController(let info): try info.encode(to: encoder)
        case .scoreToggleLayout(let info): try info.encode(to: encoder)
        }
    }

    struct Container: BaseInfo {
        var commonProperties: CommonViewProperties
        var commonOverrides: CommonViewOverrides?
        var properties: Properties

        func encode(to encoder: any Encoder) throws {
            try encoder.encode(
                properties: commonProperties, properties,
                overrides: commonOverrides
            )
        }

        init(from decoder: any Decoder) throws {
            self.commonProperties = try decoder.decodeProperties()
            self.properties = try decoder.decodeProperties()
            self.commonOverrides = try decoder.decodeOverrides()
        }

        struct Properties: ThomasSerializable {
            let type: ViewType = .container
            let items: [Item]

            private enum CodingKeys: String, CodingKey {
                case type
                case items
            }
        }

        struct Item: ThomasSerializable {
            var position: ThomasPosition
            var margin: ThomasMargin?
            var size: ThomasSize
            var view: ThomasViewInfo
            var ignoreSafeArea: Bool?

            private enum CodingKeys: String, CodingKey {
                case position
                case margin
                case size
                case view
                case ignoreSafeArea = "ignore_safe_area"
            }
        }
    }

    struct LinearLayout: BaseInfo {
        var commonProperties: CommonViewProperties
        var commonOverrides: CommonViewOverrides?
        var properties: Properties

        func encode(to encoder: any Encoder) throws {
            try encoder.encode(
                properties: commonProperties, properties,
                overrides: commonOverrides
            )
        }

        init(from decoder: any Decoder) throws {
            self.commonProperties = try decoder.decodeProperties()
            self.properties = try decoder.decodeProperties()
            self.commonOverrides = try decoder.decodeOverrides()
        }

        struct Properties: ThomasSerializable {
            let type: ViewType = .linearLayout
            var direction: ThomasDirection
            var randomizeChildren: Bool?
            var items: [Item]

            private enum CodingKeys: String, CodingKey {
                case type
                case direction
                case randomizeChildren = "randomize_children"
                case items
            }
        }

        struct Item: ThomasSerializable {
            var size: ThomasSize
            var margin: ThomasMargin?
            var view: ThomasViewInfo
            var position: ThomasPosition?
        }
    }

    struct ScrollLayout: BaseInfo {
        var commonProperties: CommonViewProperties
        var commonOverrides: CommonViewOverrides?
        var properties: Properties

        func encode(to encoder: any Encoder) throws {
            try encoder.encode(
                properties: commonProperties, properties,
                overrides: commonOverrides
            )
        }

        init(from decoder: any Decoder) throws {
            self.commonProperties = try decoder.decodeProperties()
            self.properties = try decoder.decodeProperties()
            self.commonOverrides = try decoder.decodeOverrides()
        }

        struct Properties: ThomasSerializable {
            let type: ViewType = .scrollLayout
            var direction: ThomasDirection
            var view: ThomasViewInfo

            private enum CodingKeys: String, CodingKey {
                case type
                case direction
                case view
            }
        }
    }

    struct WebView: BaseInfo {
        var commonProperties: CommonViewProperties
        var commonOverrides: CommonViewOverrides?
        var properties: Properties
        var accessible: ThomasAccessibleInfo

        func encode(to encoder: any Encoder) throws {
            try encoder.encode(
                properties: commonProperties, properties, accessible,
                overrides: commonOverrides
            )
        }

        init(from decoder: any Decoder) throws {
            self.commonProperties = try decoder.decodeProperties()
            self.properties = try decoder.decodeProperties()
            self.accessible = try decoder.decodeProperties()
            self.commonOverrides = try decoder.decodeOverrides()
        }

        struct Properties: ThomasSerializable {
            let type: ViewType = .webView
            var url: String

            private enum CodingKeys: String, CodingKey {
                case url
                case type
            }
        }
    }

    struct CustomView: BaseInfo {
        var commonProperties: CommonViewProperties
        var commonOverrides: CommonViewOverrides?
        var properties: Properties

        func encode(to encoder: any Encoder) throws {
            try encoder.encode(
                properties: commonProperties, properties,
                overrides: commonOverrides
            )
        }

        init(from decoder: any Decoder) throws {
            self.commonProperties = try decoder.decodeProperties()
            self.properties = try decoder.decodeProperties()
            self.commonOverrides = try decoder.decodeOverrides()
        }

        struct Properties: ThomasSerializable {
            let type: ViewType = .customView
            let name: String
            let properties: AirshipJSON?

            private enum CodingKeys: String, CodingKey {
                case type
                case name
                case properties
            }
        }
    }

    struct Label: BaseInfo {
        var commonProperties: CommonViewProperties
        var commonOverrides: CommonViewOverrides?

        var properties: Properties
        var accessible: ThomasAccessibleInfo
        var overrides: Overrides?

        func encode(to encoder: any Encoder) throws {
            try encoder.encode(
                properties: commonProperties, properties, accessible,
                overrides: commonOverrides, overrides
            )
        }

        init(from decoder: any Decoder) throws {
            self.commonProperties = try decoder.decodeProperties()
            self.properties = try decoder.decodeProperties()
            self.accessible = try decoder.decodeProperties()
            self.commonOverrides = try decoder.decodeOverrides()
            self.overrides = try decoder.decodeOverrides()
        }

        struct Overrides: ThomasSerializable {
            var text: [ThomasPropertyOverride<String>]?
            var ref: [ThomasPropertyOverride<String>]?
            var iconStart: [ThomasPropertyOverride<LabelIcon>]?

            private enum CodingKeys: String, CodingKey {
                case text
                case iconStart = "icon_start"
            }
        }

        enum IconType: String, Codable {
            case type = "floating"
        }

        struct LabelIcon: ThomasSerializable {
            var type: IconType
            var icon: ThomasIconInfo
            var space: Double
        }

        struct LabelAssociation: ThomasSerializable {
            enum LabelAssociationTypes: String, ThomasSerializable {
                case labels
                case describes
            }

            var viewID: String
            var type: LabelAssociationTypes
            var viewType: ViewType

            enum CodingKeys: String, CodingKey {
                case viewID = "view_id"
                case type
                case viewType = "view_type"
            }
        }

        struct Properties: ThomasSerializable {
            let type: ViewType = .label
            var text: String
            var ref: String?
            var textAppearance: ThomasTextAppearance
            var markdown: ThomasMarkDownOptions?
            var accessibilityRole: AccessibilityRole?
            var iconStart: LabelIcon?
            var labels: LabelAssociation?
            var isAccessibilityAlert: Bool?

            private enum CodingKeys: String, CodingKey {
                case type
                case text
                case ref = "ref"
                case textAppearance = "text_appearance"
                case markdown
                case accessibilityRole = "accessibility_role"
                case iconStart = "icon_start"
                case labels
                case isAccessibilityAlert = "is_accessibility_alert"
            }
        }

        enum AccessibilityRole: Codable, Equatable, Sendable {
            case heading(level: Int)

            fileprivate enum AccessibilityRoleType: String, Codable {
                case heading
            }

            private enum CodingKeys: String, CodingKey {
                case type
                case level
            }

            func encode(to encoder: any Encoder) throws {
                var container = encoder.container(keyedBy: CodingKeys.self)
                switch self {
                case .heading(let level):
                    try container.encode(AccessibilityRoleType.heading, forKey: .type)
                    try container.encode(level, forKey: .level)
                }
            }

            init(from decoder: any Decoder) throws {
                let container = try decoder.container(keyedBy: CodingKeys.self)
                let type = try container.decode(AccessibilityRoleType.self, forKey: .type)
                switch type {
                case .heading:
                    self = .heading(level: try container.decode(Int.self, forKey: .level))
                }
            }
        }
    }

    struct Media: BaseInfo {
        var commonProperties: CommonViewProperties
        var commonOverrides: CommonViewOverrides?
        var properties: Properties
        var accessible: ThomasAccessibleInfo

        func encode(to encoder: any Encoder) throws {
            try encoder.encode(
                properties: commonProperties, properties, accessible,
                overrides: commonOverrides
            )
        }

        init(from decoder: any Decoder) throws {
            self.commonProperties = try decoder.decodeProperties()
            self.properties = try decoder.decodeProperties()
            self.accessible = try decoder.decodeProperties()
            self.commonOverrides = try decoder.decodeOverrides()
        }

        enum MediaType: String, ThomasSerializable {
            case image
            case video
            case youtube
            case vimeo
        }

        struct Video: ThomasSerializable {
            var aspectRatio: Double?
            var showControls: Bool?
            var autoplay: Bool?
            var muted: Bool?
            var loop: Bool?

            enum CodingKeys: String, CodingKey {
                case aspectRatio = "aspect_ratio"
                case showControls = "show_controls"
                case autoplay
                case muted
                case loop
            }
        }

        struct Properties: ThomasSerializable {
            let type: ViewType = .media
            var url: String
            var mediaType: MediaType
            var mediaFit: ThomasMediaFit
            var video: Video?
            var cropPosition: ThomasPosition?

            private enum CodingKeys: String, CodingKey {
                case mediaType = "media_type"
                case url
                case mediaFit = "media_fit"
                case video
                case cropPosition = "position"
                case type
            }
        }
    }

    struct LabelButton: BaseInfo {
        var commonProperties: CommonViewProperties
        var commonOverrides: CommonViewOverrides?
        var properties: Properties
        var accessible: ThomasAccessibleInfo

        func encode(to encoder: any Encoder) throws {
            try encoder.encode(
                properties: commonProperties, properties, accessible,
                overrides: commonOverrides
            )
        }

        init(from decoder: any Decoder) throws {
            self.commonProperties = try decoder.decodeProperties()
            self.properties = try decoder.decodeProperties()
            self.accessible = try decoder.decodeProperties()
            self.commonOverrides = try decoder.decodeOverrides()
        }

        struct Properties: ThomasSerializable {
            let type: ViewType = .labelButton
            var identifier: String
            var clickBehaviors: [ThomasButtonClickBehavior]?
            var actions: ThomasActionsPayload?
            var label: ThomasViewInfo.Label
            var reportingMetadata: AirshipJSON?
            var tapEffect: ThomasButtonTapEffect?

            private enum CodingKeys: String, CodingKey {
                case identifier
                case clickBehaviors = "button_click"
                case actions
                case label
                case type
                case tapEffect = "tap_effect"
                case reportingMetadata = "reporting_metadata"
            }
        }
    }

    struct ButtonLayout: BaseInfo {
        var commonProperties: CommonViewProperties
        var commonOverrides: CommonViewOverrides?
        var properties: Properties
        var accessible: ThomasAccessibleInfo

        func encode(to encoder: any Encoder) throws {
            try encoder.encode(
                properties: commonProperties, properties, accessible,
                overrides: commonOverrides
            )
        }

        init(from decoder: any Decoder) throws {
            self.commonProperties = try decoder.decodeProperties()
            self.properties = try decoder.decodeProperties()
            self.accessible = try decoder.decodeProperties()
            self.commonOverrides = try decoder.decodeOverrides()
        }

        struct Properties: ThomasSerializable {
            let type: ViewType = .buttonLayout
            var identifier: String
            var clickBehaviors: [ThomasButtonClickBehavior]?
            var actions: ThomasActionsPayload?
            var reportingMetadata: AirshipJSON?
            var tapEffect: ThomasButtonTapEffect?
            var accessibilityRole: AccessibilityRole?
            var view: ThomasViewInfo

            private enum CodingKeys: String, CodingKey {
                case identifier
                case clickBehaviors = "button_click"
                case actions
                case type
                case tapEffect = "tap_effect"
                case view
                case accessibilityRole = "accessibility_role"
                case reportingMetadata = "reporting_metadata"
            }
        }

        fileprivate enum AccessibilityRoleType: String, Codable {
            case button
            case container
        }

        enum AccessibilityRole: Codable, Equatable, Sendable {
            case container
            case button

            private enum CodingKeys: String, CodingKey {
                case type
            }

            func encode(to encoder: any Encoder) throws {
                var container = encoder.container(keyedBy: CodingKeys.self)
                switch self {
                case .button:
                    try container.encode(AccessibilityRoleType.button, forKey: .type)
                case .container:
                    try container.encode(AccessibilityRoleType.container, forKey: .type)
                }
            }

            init(from decoder: any Decoder) throws {
                let container = try decoder.container(keyedBy: CodingKeys.self)
                let type = try container.decode(AccessibilityRoleType.self, forKey: .type)
                self = switch type {
                case .button: .button
                case .container: .container
                }
            }
        }
    }

    struct ImageButton: BaseInfo {
        var commonProperties: CommonViewProperties
        var commonOverrides: CommonViewOverrides?
        var properties: Properties
        var accessible: ThomasAccessibleInfo

        func encode(to encoder: any Encoder) throws {
            try encoder.encode(
                properties: commonProperties, properties, accessible,
                overrides: commonOverrides
            )
        }

        init(from decoder: any Decoder) throws {
            self.commonProperties = try decoder.decodeProperties()
            self.properties = try decoder.decodeProperties()
            self.accessible = try decoder.decodeProperties()
            self.commonOverrides = try decoder.decodeOverrides()
        }

        struct Properties: ThomasSerializable {
            let type: ViewType = .imageButton
            var identifier: String
            var clickBehaviors: [ThomasButtonClickBehavior]?
            var actions: ThomasActionsPayload?
            var reportingMetadata: AirshipJSON?
            var tapEffect: ThomasButtonTapEffect?
            var image: ButtonImage

            private enum CodingKeys: String, CodingKey {
                case identifier
                case clickBehaviors = "button_click"
                case actions
                case type
                case tapEffect = "tap_effect"
                case image
                case reportingMetadata = "reporting_metadata"
            }
        }

        enum ButtonImageType: String, Codable, Equatable, Sendable {
            case url
            case icon
        }

        enum ButtonImage: Codable, Equatable, Sendable {
            case url(ImageURL)
            case icon(ThomasIconInfo)

            private enum CodingKeys: String, CodingKey {
                case type = "type"
            }

            init(from decoder: any Decoder) throws {
                let container = try decoder.container(keyedBy: CodingKeys.self)
                let type = try container.decode(ButtonImageType.self, forKey: .type)

                self = switch type {
                case .url: .url(try ImageURL(from: decoder))
                case .icon: .icon(try ThomasIconInfo(from: decoder))
                }
            }

            func encode(to encoder: any Encoder) throws {
                switch self {
                case .icon(let info): try info.encode(to: encoder)
                case .url(let info): try info.encode(to: encoder)
                }
            }

            struct ImageURL: ThomasSerializable {
                let type: ButtonImageType = .url
                var url: String
                var mediaFit: ThomasMediaFit?
                var cropPosition: ThomasPosition?

                enum CodingKeys: String, CodingKey {
                    case url
                    case type
                    case cropPosition = "position"
                    case mediaFit = "media_fit"
                }
            }
        }
    }

    struct NubInfo: ThomasSerializable {
        var size: ThomasSize
        var margin: ThomasMargin?
        var color: ThomasColor
    }

    struct CornerRadiusInfo: ThomasSerializable {
        var topLeft: Double?
        var topRight: Double?
        var bottomLeft: Double?
        var bottomRight: Double?

        private enum CodingKeys: String, CodingKey {
            case topLeft = "top_left"
            case topRight = "top_right"
            case bottomLeft = "bottom_left"
            case bottomRight = "bottom_right"
        }
    }

    struct EmptyView: BaseInfo {
        var commonProperties: CommonViewProperties
        var commonOverrides: CommonViewOverrides?
        var properties: Properties

        func encode(to encoder: any Encoder) throws {
            try encoder.encode(
                properties: commonProperties, properties,
                overrides: commonOverrides
            )
        }


        init(commonProperties: CommonViewProperties, commonOverrides: CommonViewOverrides? = nil, properties: Properties) {
            self.commonProperties = commonProperties
            self.commonOverrides = commonOverrides
            self.properties = properties
        }


        init(from decoder: any Decoder) throws {
            self.commonProperties = try decoder.decodeProperties()
            self.properties = try decoder.decodeProperties()
            self.commonOverrides = try decoder.decodeOverrides()
        }

        struct Properties: ThomasSerializable {
            let type: ViewType = .emptyView

            private enum CodingKeys: String, CodingKey {
                case type
            }
        }
    }

    struct Pager: BaseInfo {
        var commonProperties: CommonViewProperties
        var commonOverrides: CommonViewOverrides?
        var properties: Properties

        func encode(to encoder: any Encoder) throws {
            try encoder.encode(
                properties: commonProperties, properties,
                overrides: commonOverrides
            )
        }

        init(from decoder: any Decoder) throws {
            self.commonProperties = try decoder.decodeProperties()
            self.properties = try decoder.decodeProperties()
            self.commonOverrides = try decoder.decodeOverrides()
        }

        struct Properties: ThomasSerializable {
            let type: ViewType = .pager
            let disableSwipe: Bool?
            let items: [Item]
            let gestures: [Gesture]?
            let disableSwipePredicate: [DisableSwipeSelector]?

            enum CodingKeys: String, CodingKey {
                case items = "items"
                case disableSwipe = "disable_swipe"
                case gestures = "gestures"
                case type
                case disableSwipePredicate = "disable_swipe_when"
            }
        }

        struct Item: ThomasSerializable, Identifiable {
            let identifier: String
            let view: ThomasViewInfo
            let displayActions: ThomasActionsPayload?
            let automatedActions: [ThomasAutomatedAction]?
            let accessibilityActions: [ThomasAccessibilityAction]?
            let stateActions: [ThomasStateAction]?
            let branching: ThomasPageBranching?

            enum CodingKeys: String, CodingKey {
                case identifier = "identifier"
                case view = "view"
                case displayActions = "display_actions"
                case automatedActions = "automated_actions"
                case accessibilityActions = "accessibility_actions"
                case stateActions = "state_actions"
                case branching
            }
            
            var id: String { return identifier }
        }
        
        struct DisableSwipeSelector: ThomasSerializable {
            let predicate: JSONPredicate?
            let direction: Direction
            
            enum CodingKeys: String, CodingKey {
                case predicate = "when_state_matches"
                case direction = "directions"
            }
            
            private enum DirectionCodingKeys: String, CodingKey {
                case type
            }
            
            init(from decoder: any Decoder) throws {
                let container = try decoder.container(keyedBy: CodingKeys.self)
                predicate = try container.decodeIfPresent(JSONPredicate.self, forKey: .predicate)
                
                let directionContainer = try container.nestedContainer(keyedBy: DirectionCodingKeys.self, forKey: .direction)
                direction = try directionContainer.decode(Direction.self, forKey: .type)
            }
            
            func encode(to encoder: any Encoder) throws {
                var container = encoder.container(keyedBy: CodingKeys.self)
                try container.encodeIfPresent(predicate, forKey: .predicate)
                
                var nested = container.nestedContainer(keyedBy: DirectionCodingKeys.self, forKey: .direction)
                try nested.encode(direction, forKey: .type)
            }
        }
        
        enum Direction: String, ThomasSerializable {
            case horizontal = "horizontal"
        }

        indirect enum Gesture: ThomasSerializable {
            case swipeGesture(Swipe)
            case tapGesture(Tap)
            case holdGesture(Hold)

            private enum CodingKeys: String, CodingKey {
                case type
            }

            init(from decoder: any Decoder) throws {
                let container = try decoder.container(keyedBy: CodingKeys.self)
                let type = try container.decode(GestureType.self, forKey: .type)

                self = switch type {
                case .tap: .tapGesture(try Tap(from: decoder))
                case .swipe: .swipeGesture(try Swipe(from: decoder))
                case .hold: .holdGesture(try Hold(from: decoder))
                }
            }

            func encode(to encoder: any Encoder) throws {
                switch self {
                case .swipeGesture(let gesture): try gesture.encode(to: encoder)
                case .tapGesture(let gesture): try gesture.encode(to: encoder)
                case .holdGesture(let gesture): try gesture.encode(to: encoder)
                }
            }

            enum GestureLocation: String, Codable, Equatable, Sendable {
                case top
                case bottom
                case start
                case end
                case left
                case right
                case any
            }

            enum GestureDirection: String, ThomasSerializable {
                case up
                case down
            }

            enum GestureType: String, Codable, Equatable, Sendable {
                case tap
                case swipe
                case hold
            }

            protocol Info: ThomasSerializable {
                var reportingMetadata: AirshipJSON? { get }
                var type: GestureType { get }
                var identifier: String { get }
            }

            struct GestureBehavior: ThomasSerializable {
                var actions: [ThomasActionsPayload]?
                var behaviors: [ThomasButtonClickBehavior]?
            }

            struct Swipe: Info {
                let type: GestureType = .swipe
                var identifier: String
                var reportingMetadata: AirshipJSON?
                var direction: GestureDirection
                var behavior: GestureBehavior

                enum CodingKeys: String, CodingKey {
                    case identifier
                    case reportingMetadata = "reporting_metadata"
                    case direction
                    case behavior
                    case type
                }
            }

            struct Tap: Info {
                let type: GestureType = .tap
                var identifier: String
                var reportingMetadata: AirshipJSON?
                var location: GestureLocation
                var behavior: GestureBehavior

                enum CodingKeys: String, CodingKey {
                    case identifier
                    case location
                    case behavior
                    case type
                }
            }

            struct Hold: Info {
                let type: GestureType = .hold
                var identifier: String
                var reportingMetadata: AirshipJSON?
                var pressBehavior: GestureBehavior
                var releaseBehavior: GestureBehavior

                enum CodingKeys: String, CodingKey {
                    case identifier = "identifier"
                    case pressBehavior = "press_behavior"
                    case releaseBehavior = "release_behavior"
                    case type
                }
            }
        }
    }

    enum ProgressType: String, Decodable {
        case linear = "linear"
    }

    struct Progress: Decodable, Equatable, Sendable {
        var type: ProgressType
        var color: ThomasColor

        enum CodingKeys: String, CodingKey {
            case type = "type"
            case color = "color"
        }
    }

    struct PagerIndicator: BaseInfo {
        var commonProperties: CommonViewProperties
        var commonOverrides: CommonViewOverrides?
        var properties: Properties

        func encode(to encoder: any Encoder) throws {
            try encoder.encode(
                properties: commonProperties, properties,
                overrides: commonOverrides
            )
        }

        init(from decoder: any Decoder) throws {
            self.commonProperties = try decoder.decodeProperties()
            self.properties = try decoder.decodeProperties()
            self.commonOverrides = try decoder.decodeOverrides()
        }

        struct Properties: ThomasSerializable {
            let type: ViewType = .pagerIndicator
            var bindings: Bindings
            var spacing: Double
            var automatedAccessibilityActions: [ThomasAutomatedAccessibilityAction]?

            enum CodingKeys: String, CodingKey {
                case bindings = "bindings"
                case spacing = "spacing"
                case type
                case automatedAccessibilityActions = "automated_accessibility_actions"
            }

            struct Bindings: Codable, Equatable, Sendable {
                var selected: Binding
                var unselected: Binding
            }

            struct Binding: Codable, Equatable, Sendable {
                var shapes: [ThomasShapeInfo]?
                var icon: ThomasIconInfo?
            }
        }
    }

    struct StoryIndicator: BaseInfo {
        var commonProperties: CommonViewProperties
        var commonOverrides: CommonViewOverrides?
        var properties: Properties

        func encode(to encoder: any Encoder) throws {
            try encoder.encode(
                properties: commonProperties, properties,
                overrides: commonOverrides
            )
        }

        init(from decoder: any Decoder) throws {
            self.commonProperties = try decoder.decodeProperties()
            self.properties = try decoder.decodeProperties()
            self.commonOverrides = try decoder.decodeOverrides()
        }

        struct Properties: ThomasSerializable {
            let type: ViewType = .storyIndicator
            var source: Source
            var style: Style
            var automatedAccessibilityActions: [ThomasAutomatedAccessibilityAction]?

            enum CodingKeys: String, CodingKey {
                case source = "source"
                case style = "style"
                case type
                case automatedAccessibilityActions = "automated_accessibility_actions"
            }
        }

        struct Source: ThomasSerializable {
            let type: IndicatorType

            enum IndicatorType: String, ThomasSerializable {
                case pager = "pager"
                case currentPage = "current_page"
            }
        }

        enum Style: ThomasSerializable {
            case linearProgress(LinearProgress)

            enum StyleType: String, Codable, Equatable, Sendable {
                case linearProgress = "linear_progress"
            }

            private enum CodingKeys: String, CodingKey {
                case type
            }

            init(from decoder: any Decoder) throws {
                let container = try decoder.container(keyedBy: CodingKeys.self)
                let type = try container.decode(StyleType.self, forKey: .type)

                self = switch type {
                case .linearProgress: .linearProgress(try LinearProgress(from: decoder))
                }
            }

            func encode(to encoder: any Encoder) throws {
                switch self {
                case .linearProgress(let style): try style.encode(to: encoder)
                }
            }

            enum LayoutDirection: String, ThomasSerializable {
                case vertical = "vertical"
                case horizontal = "horizontal"
            }

            enum ProgressSizingType: String, Codable, Equatable, Sendable {
                case equal
                case pageDuration = "page_duration"
            }

            struct LinearProgress: ThomasSerializable {
                let type: StyleType = .linearProgress
                var direction: LayoutDirection
                var sizing: ProgressSizingType?
                var spacing: Double?
                var progressColor: ThomasColor
                var trackColor: ThomasColor

                private enum CodingKeys: String, CodingKey {
                    case type
                    case direction
                    case sizing
                    case spacing
                    case progressColor = "progress_color"
                    case trackColor = "track_color"
                }
            }
        }
    }

    struct PagerController: BaseInfo {
        var commonProperties: CommonViewProperties
        var commonOverrides: CommonViewOverrides?
        var properties: Properties

        func encode(to encoder: any Encoder) throws {
            try encoder.encode(
                properties: commonProperties, properties,
                overrides: commonOverrides
            )
        }

        init(from decoder: any Decoder) throws {
            self.commonProperties = try decoder.decodeProperties()
            self.properties = try decoder.decodeProperties()
            self.commonOverrides = try decoder.decodeOverrides()
        }

        struct Properties: ThomasSerializable {
            let type: ViewType = .pagerController
            var view: ThomasViewInfo
            var identifier: String
            let branching: ThomasPagerControllerBranching?

            enum CodingKeys: String, CodingKey {
                case view = "view"
                case identifier = "identifier"
                case type
                case branching
            }
        }
    }

    struct FormController: BaseInfo {
        var commonProperties: CommonViewProperties
        var commonOverrides: CommonViewOverrides?
        var properties: Properties

        func encode(to encoder: any Encoder) throws {
            try encoder.encode(
                properties: commonProperties, properties,
                overrides: commonOverrides
            )
        }

        init(from decoder: any Decoder) throws {
            self.commonProperties = try decoder.decodeProperties()
            self.properties = try decoder.decodeProperties()
            self.commonOverrides = try decoder.decodeOverrides()
        }

        struct Properties: ThomasSerializable {
            let type: ViewType = .formController
            var identifier: String
            var submit: ThomasFormSubmitBehavior?
            var view: ThomasViewInfo
            var responseType: String?
            var formEnableBehaviors: [ThomasEnableBehavior]?
            var validationMode: ThomasFormValidationMode?

            enum CodingKeys: String, CodingKey {
                case identifier = "identifier"
                case submit = "submit"
                case view = "view"
                case responseType = "response_type"
                case formEnableBehaviors = "form_enabled"
                case type
                case validationMode = "validation_mode"
            }
        }
    }

    struct StateController: BaseInfo {
        var commonProperties: CommonViewProperties
        var commonOverrides: CommonViewOverrides?
        var properties: Properties
        
        func encode(to encoder: any Encoder) throws {
            try encoder.encode(
                properties: commonProperties, properties,
                overrides: commonOverrides
            )
        }
        
        init(from decoder: any Decoder) throws {
            self.commonProperties = try decoder.decodeProperties()
            self.properties = try decoder.decodeProperties()
            self.commonOverrides = try decoder.decodeOverrides()
        }
        
        struct Properties: ThomasSerializable {
            let type: ViewType = .stateController
            var view: ThomasViewInfo
            var initialState: AirshipJSON?
            enum CodingKeys: String, CodingKey {
                case view
                case type
                case initialState = "initial_state"
            }
        }
    }

    struct NPSController: BaseInfo {
        var commonProperties: CommonViewProperties
        var commonOverrides: CommonViewOverrides?
        var properties: Properties

        func encode(to encoder: any Encoder) throws {
            try encoder.encode(
                properties: commonProperties, properties,
                overrides: commonOverrides
            )
        }

        init(from decoder: any Decoder) throws {
            self.commonProperties = try decoder.decodeProperties()
            self.properties = try decoder.decodeProperties()
            self.commonOverrides = try decoder.decodeOverrides()
        }

        struct Properties: ThomasSerializable {
            let type: ViewType = .npsController
            var identifier: String
            var submit: ThomasFormSubmitBehavior?
            var npsIdentifier: String
            var view: ThomasViewInfo
            var responseType: String?
            var formEnableBehaviors: [ThomasEnableBehavior]?
            var validationMode: ThomasFormValidationMode?

            enum CodingKeys: String, CodingKey {
                case identifier
                case submit
                case view
                case npsIdentifier = "nps_identifier"
                case responseType = "response_type"
                case formEnableBehaviors = "form_enabled"
                case type
                case validationMode = "validation_mode"
            }
        }
    }

    struct CheckboxController: BaseInfo {
        var commonProperties: CommonViewProperties
        var commonOverrides: CommonViewOverrides?

        var properties: Properties
        var accessible: ThomasAccessibleInfo
        var validation: ThomasValidationInfo

        func encode(to encoder: any Encoder) throws {
            try encoder.encode(
                properties: commonProperties, properties, accessible, validation,
                overrides: commonOverrides
            )
        }

        init(from decoder: any Decoder) throws {
            self.commonProperties = try decoder.decodeProperties()
            self.properties = try decoder.decodeProperties()
            self.accessible = try decoder.decodeProperties()
            self.validation = try decoder.decodeProperties()
            self.commonOverrides = try decoder.decodeOverrides()
        }

        struct Properties: ThomasSerializable {
            let type: ViewType = .checkboxController
            var identifier: String
            var view: ThomasViewInfo
            var minSelection: Int?
            var maxSelection: Int?

            enum CodingKeys: String, CodingKey {
                case identifier
                case view
                case type
                case minSelection = "min_selection"
                case maxSelection = "max_selection"
            }
        }
    }

    struct RadioInputController: BaseInfo {
        var commonProperties: CommonViewProperties
        var commonOverrides: CommonViewOverrides?

        var properties: Properties
        var accessible: ThomasAccessibleInfo
        var validation: ThomasValidationInfo

        func encode(to encoder: any Encoder) throws {
            try encoder.encode(
                properties: commonProperties, properties, accessible, validation,
                overrides: commonOverrides
            )
        }

        init(from decoder: any Decoder) throws {
            self.commonProperties = try decoder.decodeProperties()
            self.properties = try decoder.decodeProperties()
            self.accessible = try decoder.decodeProperties()
            self.validation = try decoder.decodeProperties()
            self.commonOverrides = try decoder.decodeOverrides()
        }

        struct Properties: ThomasSerializable {
            let type: ViewType = .radioInputController
            var identifier: String
            var view: ThomasViewInfo
            var attributeName: ThomasAttributeName?

            enum CodingKeys: String, CodingKey {
                case identifier
                case view
                case attributeName = "attribute_name"
                case type
            }
        }
    }

    struct ScoreController: BaseInfo {
        var commonProperties: CommonViewProperties
        var commonOverrides: CommonViewOverrides?

        var properties: Properties
        var accessible: ThomasAccessibleInfo
        var validation: ThomasValidationInfo

        func encode(to encoder: any Encoder) throws {
            try encoder.encode(
                properties: commonProperties, properties, accessible, validation,
                overrides: commonOverrides
            )
        }

        init(from decoder: any Decoder) throws {
            self.commonProperties = try decoder.decodeProperties()
            self.properties = try decoder.decodeProperties()
            self.accessible = try decoder.decodeProperties()
            self.validation = try decoder.decodeProperties()
            self.commonOverrides = try decoder.decodeOverrides()
        }

        struct Properties: ThomasSerializable {
            let type: ViewType = .radioInputController
            var identifier: String
            var view: ThomasViewInfo
            var attributeName: ThomasAttributeName?

            enum CodingKeys: String, CodingKey {
                case identifier
                case view
                case attributeName = "attribute_name"
                case type
            }
        }
    }


    struct ScoreToggleLayout: BaseInfo {
        let properties: Properties
        var commonProperties: CommonViewProperties
        var commonOverrides: CommonViewOverrides?
        var accessible: ThomasAccessibleInfo
        var validation: ThomasValidationInfo

        func encode(to encoder: any Encoder) throws {
            try encoder.encode(
                properties: commonProperties, properties, accessible, validation,
                overrides: commonOverrides
            )
        }

        init(from decoder: any Decoder) throws {
            self.properties = try decoder.decodeProperties()
            self.commonProperties = try decoder.decodeProperties()
            self.commonOverrides = try decoder.decodeOverrides()
            self.accessible = try decoder.decodeProperties()
            self.validation = try decoder.decodeProperties()
        }

        struct Properties: ThomasSerializable {
            var identifier: String
            var attributeValue: ThomasAttributeValue?
            var onToggleOn: ToggleActions
            var onToggleOff: ToggleActions
            var view: ThomasViewInfo
            var reportingValue: AirshipJSON

            private enum CodingKeys: String, CodingKey {
                case identifier
                case attributeValue = "attribute_value"
                case onToggleOn = "on_toggle_on"
                case onToggleOff = "on_toggle_off"
                case view
                case reportingValue = "reporting_value"
            }
        }
    }


    struct TextInput: BaseInfo {
        var commonProperties: CommonViewProperties
        var properties: Properties
        var accessible: ThomasAccessibleInfo
        var validation: ThomasValidationInfo
        var commonOverrides: CommonViewOverrides?
        var overrides: Overrides?

        func encode(to encoder: any Encoder) throws {
            try encoder.encode(
                properties: commonProperties, properties, accessible, validation,
                overrides: commonOverrides, overrides
            )
        }

        init(from decoder: any Decoder) throws {
            self.commonProperties = try decoder.decodeProperties()
            self.properties = try decoder.decodeProperties()
            self.accessible = try decoder.decodeProperties()
            self.validation = try decoder.decodeProperties()
            self.commonOverrides = try decoder.decodeOverrides()
            self.overrides = try decoder.decodeOverrides()
        }

        enum IconEndType: String, Codable {
            case floating = "floating"
        }

        struct IconEndInfo: ThomasSerializable {
            var type: IconEndType = .floating
            var icon: ThomasIconInfo
        }

        struct Properties: ThomasSerializable {
            let type: ViewType = .textInput
            var identifier: String
            var attributeName: ThomasAttributeName?
            var placeholder: String?
            var textAppearance: ThomasTextAppearance
            var inputType: TextInputType
            var iconEnd: IconEndInfo?
            var emailRegistration: ThomasEmailRegistrationOption?
            var smsLocales: [ThomasSMSLocale]?

            enum CodingKeys: String, CodingKey {
                case attributeName = "attribute_name"
                case textAppearance = "text_appearance"
                case identifier
                case placeholder = "place_holder"
                case inputType = "input_type"
                case type
                case iconEnd = "icon_end"
                case emailRegistration = "email_registration"
                case smsLocales = "locales"
            }
        }

        struct Overrides: ThomasSerializable {
            var iconEnd: [ThomasPropertyOverride<IconEndInfo>]?

            enum CodingKeys: String, CodingKey {
                case iconEnd = "icon_end"
            }
        }

        enum TextInputType: String, ThomasSerializable {
            case email
            case number
            case text
            case textMultiline = "text_multiline"
            case sms
        }
    }


    struct Toggle: BaseInfo {
        var commonProperties: CommonViewProperties
        var properties: Properties
        var accessible: ThomasAccessibleInfo
        var validation: ThomasValidationInfo
        var commonOverrides: CommonViewOverrides?

        func encode(to encoder: any Encoder) throws {
            try encoder.encode(
                properties: commonProperties, properties, accessible, validation,
                overrides: commonOverrides
            )
        }

        init(from decoder: any Decoder) throws {
            self.commonProperties = try decoder.decodeProperties()
            self.properties = try decoder.decodeProperties()
            self.accessible = try decoder.decodeProperties()
            self.validation = try decoder.decodeProperties()
            self.commonOverrides = try decoder.decodeOverrides()
        }

        struct Properties: ThomasSerializable {
            let type: ViewType = .toggle
            var identifier: String
            var style: ThomasToggleStyleInfo
            var attributeName: ThomasAttributeName?
            var attributeValue: ThomasAttributeValue?

            enum CodingKeys: String, CodingKey {
                case style
                case identifier
                case attributeName = "attribute_name"
                case attributeValue = "attribute_value"
                case type
            }
        }
    }

    struct ToggleActions: ThomasSerializable {
        var stateActions: [ThomasStateAction]?

        enum CodingKeys: String, CodingKey {
            case stateActions = "state_actions"
        }
    }

    struct BasicToggleLayout: BaseInfo {
        let properties: Properties
        var commonProperties: CommonViewProperties
        var commonOverrides: CommonViewOverrides?
        var accessible: ThomasAccessibleInfo
        var validation: ThomasValidationInfo

        func encode(to encoder: any Encoder) throws {
            try encoder.encode(
                properties: commonProperties, properties, accessible, validation,
                overrides: commonOverrides
            )
        }

        init(from decoder: any Decoder) throws {
            self.properties = try decoder.decodeProperties()
            self.commonProperties = try decoder.decodeProperties()
            self.commonOverrides = try decoder.decodeOverrides()
            self.accessible = try decoder.decodeProperties()
            self.validation = try decoder.decodeProperties()
        }

        struct Properties: ThomasSerializable {
            var identifier: String
            var attributeName: ThomasAttributeName?
            var attributeValue: ThomasAttributeValue?
            var onToggleOn: ToggleActions
            var onToggleOff: ToggleActions
            var view: ThomasViewInfo

            private enum CodingKeys: String, CodingKey {
                case identifier
                case attributeName = "attribute_name"
                case attributeValue = "attribute_value"
                case onToggleOn = "on_toggle_on"
                case onToggleOff = "on_toggle_off"
                case view
            }
        }
    }

    struct CheckboxToggleLayout: BaseInfo {
        let properties: Properties
        var commonProperties: CommonViewProperties
        var commonOverrides: CommonViewOverrides?
        var accessible: ThomasAccessibleInfo
        var validation: ThomasValidationInfo

        func encode(to encoder: any Encoder) throws {
            try encoder.encode(
                properties: commonProperties, properties, accessible, validation,
                overrides: commonOverrides
            )
        }

        init(from decoder: any Decoder) throws {
            self.properties = try decoder.decodeProperties()
            self.commonProperties = try decoder.decodeProperties()
            self.commonOverrides = try decoder.decodeOverrides()
            self.accessible = try decoder.decodeProperties()
            self.validation = try decoder.decodeProperties()
        }

        struct Properties: ThomasSerializable {
            var identifier: String
            var onToggleOn: ToggleActions
            var onToggleOff: ToggleActions
            var view: ThomasViewInfo
            var reportingValue: AirshipJSON

            private enum CodingKeys: String, CodingKey {
                case identifier
                case onToggleOn = "on_toggle_on"
                case onToggleOff = "on_toggle_off"
                case view
                case reportingValue = "reporting_value"
            }
        }
    }

    struct RadioInputToggleLayout: BaseInfo {
        let properties: Properties
        var commonProperties: CommonViewProperties
        var commonOverrides: CommonViewOverrides?
        var accessible: ThomasAccessibleInfo
        var validation: ThomasValidationInfo

        func encode(to encoder: any Encoder) throws {
            try encoder.encode(
                properties: commonProperties, properties, accessible, validation,
                overrides: commonOverrides
            )
        }

        init(from decoder: any Decoder) throws {
            self.properties = try decoder.decodeProperties()
            self.commonProperties = try decoder.decodeProperties()
            self.commonOverrides = try decoder.decodeOverrides()
            self.accessible = try decoder.decodeProperties()
            self.validation = try decoder.decodeProperties()
        }

        struct Properties: ThomasSerializable {
            var identifier: String
            var attributeValue: ThomasAttributeValue?
            var onToggleOn: ToggleActions
            var onToggleOff: ToggleActions
            var view: ThomasViewInfo
            var reportingValue: AirshipJSON

            private enum CodingKeys: String, CodingKey {
                case identifier
                case attributeValue = "attribute_value"
                case onToggleOn = "on_toggle_on"
                case onToggleOff = "on_toggle_off"
                case view
                case reportingValue = "reporting_value"
            }
        }
    }
    
    struct Checkbox: BaseInfo {
        var commonProperties: CommonViewProperties
        var commonOverrides: CommonViewOverrides?
        var properties: Properties
        var accessible: ThomasAccessibleInfo

        func encode(to encoder: any Encoder) throws {
            try encoder.encode(
                properties: commonProperties, properties, accessible,
                overrides: commonOverrides
            )
        }

        init(from decoder: any Decoder) throws {
            self.commonProperties = try decoder.decodeProperties()
            self.properties = try decoder.decodeProperties()
            self.accessible = try decoder.decodeProperties()
            self.commonOverrides = try decoder.decodeOverrides()
        }

        struct Properties: ThomasSerializable {
            let type: ViewType = .checkbox
            var reportingValue: AirshipJSON
            var style: ThomasToggleStyleInfo
            var identifier: String? // Added later so its treated as optional.

            enum CodingKeys: String, CodingKey {
                case style
                case reportingValue = "reporting_value"
                case type
                case identifier
            }
        }
    }

    struct RadioInput: BaseInfo {
        var commonProperties: CommonViewProperties
        var commonOverrides: CommonViewOverrides?
        var properties: Properties
        var accessible: ThomasAccessibleInfo

        func encode(to encoder: any Encoder) throws {
            try encoder.encode(
                properties: commonProperties, properties, accessible,
                overrides: commonOverrides
            )
        }

        init(from decoder: any Decoder) throws {
            self.commonProperties = try decoder.decodeProperties()
            self.properties = try decoder.decodeProperties()
            self.accessible = try decoder.decodeProperties()
            self.commonOverrides = try decoder.decodeOverrides()
        }

        struct Properties: ThomasSerializable {
            let type: ViewType = .radioInput
            var reportingValue: AirshipJSON
            var style: ThomasToggleStyleInfo
            var attributeValue: ThomasAttributeValue?
            var identifier: String? // Added later so its treated as optional.

            enum CodingKeys: String, CodingKey {
                case style
                case identifier
                case reportingValue = "reporting_value"
                case attributeValue = "attribute_value"
                case type
            }
        }
    }

    struct Score: BaseInfo {
        var commonProperties: CommonViewProperties
        var commonOverrides: CommonViewOverrides?

        var properties: Properties
        var accessible: ThomasAccessibleInfo
        var validation: ThomasValidationInfo

        func encode(to encoder: any Encoder) throws {
            try encoder.encode(
                properties: commonProperties, properties, accessible, validation,
                overrides: commonOverrides
            )
        }

        init(from decoder: any Decoder) throws {
            self.commonProperties = try decoder.decodeProperties()
            self.properties = try decoder.decodeProperties()
            self.accessible = try decoder.decodeProperties()
            self.validation = try decoder.decodeProperties()
            self.commonOverrides = try decoder.decodeOverrides()
        }

        struct Properties: ThomasSerializable {
            let type: ViewType = .score
            var identifier: String
            var style: ScoreStyle
            var attributeName: ThomasAttributeName?

            private enum CodingKeys: String, CodingKey {
                case identifier
                case style
                case attributeName = "attribute_name"
                case type
            }
        }

        enum ScoreStyle: ThomasSerializable {
            case numberRange(NumberRange)

            enum ScoreStyleType: String, ThomasSerializable {
                case numberRange = "number_range"
            }

            private enum CodingKeys: String, CodingKey {
                case type
            }

            init(from decoder: any Decoder) throws {
                let container = try decoder.container(keyedBy: CodingKeys.self)
                let type = try container.decode(ScoreStyleType.self, forKey: .type)

                self = switch type {
                case .numberRange: .numberRange(try NumberRange(from: decoder))
                }
            }

            func encode(to encoder: any Encoder) throws {
                switch self {
                case .numberRange(let info): try info.encode(to: encoder)
                }
            }

            struct NumberRange: ThomasSerializable {
                let type: ScoreStyleType = .numberRange
                var spacing: Double?
                var bindings: Bindings
                var start: Int
                var end: Int
                let wrapping: Wrapping?

                struct Wrapping: ThomasSerializable {
                    let lineSpacing: Double?
                    let maxItemsPerLine: Int?

                    enum CodingKeys: String, CodingKey {
                        case lineSpacing = "line_spacing"
                        case maxItemsPerLine = "max_items_per_line"
                    }
                }

                enum CodingKeys: String, CodingKey {
                    case spacing
                    case bindings
                    case start
                    case end
                    case type
                    case wrapping
                }

                struct Bindings: ThomasSerializable {
                    var selected: Binding
                    var unselected: Binding
                }

                struct Binding: ThomasSerializable {
                    var shapes: [ThomasShapeInfo]?
                    var textAppearance: ThomasTextAppearance?

                    private enum CodingKeys: String, CodingKey {
                        case shapes
                        case textAppearance = "text_appearance"
                    }
                }
            }

        }
    }

    struct IconView: BaseInfo {
        var properties: Properties
        var accessible: ThomasAccessibleInfo
        var commonProperties: ThomasViewInfo.CommonViewProperties
        var commonOverrides: ThomasViewInfo.CommonViewOverrides?
        var overrides: Overrides?

        init(from decoder: any Decoder) throws {
            self.commonProperties = try decoder.decodeProperties()
            self.properties = try decoder.decodeProperties()
            self.accessible = try decoder.decodeProperties()
            self.commonOverrides = try decoder.decodeOverrides()
            self.overrides = try decoder.decodeOverrides()
        }

        func encode(to encoder: any Encoder) throws {
            try encoder.encode(
                properties: commonProperties, properties, accessible,
                overrides: commonOverrides, overrides
            )
        }

        struct Properties: ThomasSerializable {
            var icon: ThomasIconInfo
        }

        struct Overrides: ThomasSerializable {
            var icon: [ThomasPropertyOverride<ThomasIconInfo>]?
        }
    }

    struct CommonViewOverrides: ThomasSerializable {
        var border: [ThomasPropertyOverride<ThomasBorder>]?
        var backgroundColor: [ThomasPropertyOverride<ThomasColor>]?

        enum CodingKeys: String, CodingKey {
            case border
            case backgroundColor = "background_color"
        }
    }

    struct CommonViewProperties: ThomasSerializable {
        var border: ThomasBorder?
        var backgroundColor: ThomasColor?
        var visibility: ThomasVisibilityInfo?
        var eventHandlers: [ThomasEventHandler]?
        var enabled: [ThomasEnableBehavior]?
        var stateTriggers: [ThomasStateTriggers]?

        enum CodingKeys: String, CodingKey {
            case border
            case backgroundColor = "background_color"
            case visibility
            case eventHandlers = "event_handlers"
            case enabled
            case stateTriggers = "state_triggers"
        }
    }
}

fileprivate extension Encoder {
    func encode(properties: (any Encodable)?..., overrides: (any Encodable)?...) throws {
        try properties.forEach { codable in
            try codable?.encode(to: self)
        }

        let overrides = overrides.compactMap { $0 }
        if !overrides.isEmpty {
            try ViewOverridesEncodable(overrides: overrides).encode(to: self)
        }
    }
}

fileprivate extension Decoder {
    func decodeProperties<T: Decodable>() throws -> T {
        return try T(from: self)
    }

    func decodeOverrides<T: Decodable>() throws -> T? {
        return try ViewOverridesDecodable<T>(from: self).overrides
    }
}

fileprivate struct ViewOverridesEncodable: Encodable {
    private let wrapper: Wrapper?

    init(overrides: [any Encodable]) {
        self.wrapper = Wrapper(overrides: overrides)
    }

    enum CodingKeys: String, CodingKey {
        case wrapper = "view_overrides"
    }

    struct Wrapper: Encodable {
        var overrides: [any Encodable]
        func encode(to encoder: any Encoder) throws {
            try overrides.forEach {
                try $0.encode(to: encoder)
            }
        }
    }
}

fileprivate struct ViewOverridesDecodable<T: Decodable>: Decodable {
    var overrides: T?
    enum CodingKeys: String, CodingKey {
        case overrides = "view_overrides"
    }
}


