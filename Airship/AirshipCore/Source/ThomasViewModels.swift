/* Copyright Airship and Contributors */

import Foundation

/// AirshipLayout
public struct AirshipLayout: Codable, Equatable, Sendable {
    /// The view DSL
    let view: ViewModel
    
    /// Layout DSL version
    let version: Int
    
    /// Presentation configuration
    let presentation: PresentationModel

    enum CodingKeys: String, CodingKey {
        case view = "view"
        case version = "version"
        case presentation = "presentation"
    }
}

enum PresentationModelType: String, Codable, Equatable, Sendable {
    case modal
    case banner
    case embedded
}

enum PresentationModel: Codable, Equatable, Sendable {
    case banner(BannerPresentationModel)
    case modal(ModalPresentationModel)
    case embedded(EmbeddedPresentationModel)

    enum CodingKeys: String, CodingKey {
        case type = "type"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(
            PresentationModelType.self,
            forKey: .type
        )
        let singleValueContainer = try decoder.singleValueContainer()

        switch type {
        case .banner:
            self = .banner(
                try singleValueContainer.decode(BannerPresentationModel.self)
            )
        case .modal:
            self = .modal(
                try singleValueContainer.decode(ModalPresentationModel.self)
            )
        case .embedded:
            self = .embedded(
                try singleValueContainer.decode(EmbeddedPresentationModel.self)
            )
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        let content: Encodable
        
        switch self {
        case .banner(let model):
            content = model
        case .modal(let model):
            content = model
        case .embedded(let model):
            content = model
        }
        
        try container.encode(content)
    }
}

struct BannerPresentationModel: Codable, Equatable, Sendable {
    let type = PresentationModelType.banner
    let duration: Int?
    let placementSelectors: [BannerPlacementSelector]?
    let defaultPlacement: BannerPlacement

    enum CodingKeys: String, CodingKey {
        case duration = "duration_milliseconds"
        case placementSelectors = "placement_selectors"
        case defaultPlacement = "default_placement"
        case type
    }
}

struct BannerPlacement: Codable, Equatable, Sendable {
    let margin: Margin?
    let size: ConstrainedSize
    let position: BannerPosition
    let ignoreSafeArea: Bool?
    let border: Border?
    let backgroundColor: ThomasColor?

    enum CodingKeys: String, CodingKey {
        case margin = "margin"
        case size = "size"
        case position = "position"
        case ignoreSafeArea = "ignore_safe_area"
        case border = "border"
        case backgroundColor = "background_color"
    }
}

struct BannerPlacementSelector: Codable, Equatable, Sendable {
    let placement: BannerPlacement
    let windowSize: WindowSize?
    let orientation: Orientation?

    enum CodingKeys: String, CodingKey {
        case placement = "placement"
        case windowSize = "windowSize"
        case orientation = "orientation"
    }
}

struct ModalPresentationModel: Codable, Equatable, Sendable {
    let type = PresentationModelType.modal
    let placementSelectors: [ModalPlacementSelector]?
    let defaultPlacement: ModalPlacement
    let dismissOnTouchOutside: Bool?
    let device: Device?

    enum CodingKeys: String, CodingKey {
        case placementSelectors = "placement_selectors"
        case defaultPlacement = "default_placement"
        case dismissOnTouchOutside = "dismiss_on_touch_outside"
        case device = "device"
        case type
    }

    struct Device: Codable, Equatable, Sendable {
        let orientationLock: Orientation?
        enum CodingKeys: String, CodingKey {
            case orientationLock = "lock_orientation"
        }
    }
}

struct ModalPlacement: Codable, Equatable, Sendable {
    let margin: Margin?
    let size: ConstrainedSize
    let position: Position?
    let shade: ThomasColor?
    let ignoreSafeArea: Bool?
    let device: Device?
    let border: Border?
    let backgroundColor: ThomasColor?

    enum CodingKeys: String, CodingKey, Sendable {
        case margin = "margin"
        case size = "size"
        case position = "position"
        case shade = "shade_color"
        case ignoreSafeArea = "ignore_safe_area"
        case device = "device"
        case border = "border"
        case backgroundColor = "background_color"
    }

    struct Device: Codable, Equatable, Sendable {
        let orientationLock: Orientation?
        enum CodingKeys: String, CodingKey {
            case orientationLock = "lock_orientation"
        }
    }

}

struct ModalPlacementSelector: Codable, Equatable, Sendable {
    let placement: ModalPlacement
    let windowSize: WindowSize?
    let orientation: Orientation?

    enum CodingKeys: String, CodingKey {
        case placement = "placement"
        case windowSize = "window_size"
        case orientation = "orientation"
    }
}

struct EmbeddedPresentationModel: Codable, Equatable, Sendable {
    let type = PresentationModelType.embedded
    let placementSelectors: [EmbeddedPlacementSelector]?
    let defaultPlacement: EmbeddedPlacement
    let embeddedID: String

    enum CodingKeys: String, CodingKey {
        case defaultPlacement = "default_placement"
        case placementSelectors = "placement_selectors"
        case embeddedID = "embedded_id"
        case type
    }
}

struct EmbeddedPlacement: Codable, Equatable, Sendable {
    let margin: Margin?
    let size: ConstrainedSize
    let border: Border?
    let backgroundColor: ThomasColor?

    enum CodingKeys: String, CodingKey {
        case margin = "margin"
        case size = "size"
        case border = "border"
        case backgroundColor = "background_color"
    }
}

struct EmbeddedPlacementSelector: Codable, Equatable, Sendable {
    let placement: EmbeddedPlacement
    let windowSize: WindowSize?
    let orientation: Orientation?

    enum CodingKeys: String, CodingKey {
        case placement = "placement"
        case windowSize = "window_size"
        case orientation = "orientation"
    }
}

enum WindowSize: String, Codable, Equatable, Sendable {
    case small = "small"
    case medium = "medium"
    case large = "large"
}

enum Orientation: String, Codable, Equatable, Sendable {
    case portrait = "portrait"
    case landscape = "landscape"
}

enum ShapeModelType: String, Codable, Equatable, Sendable {
    case rectangle = "rectangle"
    case ellipse = "ellipse"
}

enum ToggleStyleModelType: String, Codable, Equatable, Sendable {
    case switchStyle = "switch"
    case checkboxStyle = "checkbox"
}

enum ToggleStyleModel: Codable, Equatable, Sendable {
    case switchStyle(SwitchToggleStyleModel)
    case checkboxStyle(CheckboxToggleStyleModel)

    enum CodingKeys: String, CodingKey {
        case type = "type"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(
            ToggleStyleModelType.self,
            forKey: .type
        )
        let singleValueContainer = try decoder.singleValueContainer()

        switch type {
        case .switchStyle:
            self = .switchStyle(
                try singleValueContainer.decode(SwitchToggleStyleModel.self)
            )
        case .checkboxStyle:
            self = .checkboxStyle(
                try singleValueContainer.decode(CheckboxToggleStyleModel.self)
            )
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        let content: Encodable
        
        switch self {
        case .checkboxStyle(let model):
            content = model
        case .switchStyle(let model):
            content = model
        }
        
        try container.encode(content)
    }
}

enum ViewModelType: String, Codable {
    case container = "container"
    case linearLayout = "linear_layout"
    case webView = "web_view"
    case customView = "custom_view"
    case scrollLayout = "scroll_layout"
    case media = "media"
    case label = "label"
    case labelButton = "label_button"
    case imageButton = "image_button"
    case emptyView = "empty_view"
    case pager = "pager"
    case pagerIndicator = "pager_indicator"
    case storyIndicator = "story_indicator"
    case pagerController = "pager_controller"
    case formController = "form_controller"
    case checkbox = "checkbox"
    case checkboxController = "checkbox_controller"
    case radioInput = "radio_input"
    case radioInputController = "radio_input_controller"
    case textInput = "text_input"
    case score = "score"
    case npsController = "nps_form_controller"
    case toggle = "toggle"
    case stateController = "state_controller"
}

indirect enum PagerGestureModel: Codable, Equatable, Sendable {
    case swipeGesture(PagerDragGesture)
    case tapGesture(PagerTapGesture)
    case holdGesture(PagerHoldGesture)
    
    private enum CodingKeys: String, CodingKey {
        case type
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(PagerGestureType.self, forKey: .type)
        let singleValueContainer = try decoder.singleValueContainer()
        
        switch type {
        case .tap:
            self = .tapGesture(
                try singleValueContainer.decode(PagerTapGesture.self)
            )
        case .swipe:
            self = .swipeGesture(
                try singleValueContainer.decode(PagerDragGesture.self)
            )
        case .hold:
            self = .holdGesture(
                try singleValueContainer.decode(PagerHoldGesture.self)
            )
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        let content: Encodable
        
        switch self {
        case .swipeGesture(let gesture):
            content = gesture
        case .tapGesture(let gesture):
            content = gesture
        case .holdGesture(let gesture):
            content = gesture
        }
        
        try container.encode(content)
    }
}

indirect enum ViewModel: Codable, Equatable, Sendable {
    case container(ContainerModel)
    case linearLayout(LinearLayoutModel)
    #if !os(tvOS) && !os(watchOS)
    case webView(WebViewModel)
    #endif
    case customView(CustomViewModel)
    case scrollLayout(ScrollLayoutModel)
    case media(MediaModel)
    case label(LabelModel)
    case labelButton(LabelButtonModel)
    case imageButton(ImageButtonModel)
    case emptyView(EmptyViewModel)
    case pager(PagerModel)
    case pagerIndicator(PagerIndicatorModel)
    case storyIndicator(StoryIndicatorModel)
    case pagerController(PagerControllerModel)
    case formController(FormControllerModel)
    case checkbox(CheckboxModel)
    case checkboxController(CheckboxControllerModel)
    case radioInput(RadioInputModel)
    case radioInputController(RadioInputControllerModel)
    case textInput(TextInputModel)
    case score(ScoreModel)
    case npsController(NpsControllerModel)
    case toggle(ToggleModel)
    case stateController(StateControllerModel)

    private enum CodingKeys: String, CodingKey {
        case type
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(ViewModelType.self, forKey: .type)
        let singleValueContainer = try decoder.singleValueContainer()

        switch type {
        case .container:
            self = .container(
                try singleValueContainer.decode(ContainerModel.self)
            )
        case .linearLayout:
            self = .linearLayout(
                try singleValueContainer.decode(LinearLayoutModel.self)
            )

        case .webView:
            #if os(tvOS) || os(watchOS)
            throw AirshipErrors.error(
                "Webview not available on tvOS and watchOS"
            )
            #else
            self = .webView(
                try singleValueContainer.decode(WebViewModel.self)
            )
            #endif

        case .scrollLayout:
            self = .scrollLayout(
                try singleValueContainer.decode(ScrollLayoutModel.self)
            )
        case .media:
            self = .media(try singleValueContainer.decode(MediaModel.self))
        case .label:
            self = .label(try singleValueContainer.decode(LabelModel.self))
        case .labelButton:
            self = .labelButton(
                try singleValueContainer.decode(LabelButtonModel.self)
            )
        case .imageButton:
            self = .imageButton(
                try singleValueContainer.decode(ImageButtonModel.self)
            )
        case .emptyView:
            self = .emptyView(
                try singleValueContainer.decode(EmptyViewModel.self)
            )
        case .pager:
            self = .pager(try singleValueContainer.decode(PagerModel.self))
        case .pagerIndicator:
            self = .pagerIndicator(
                try singleValueContainer.decode(PagerIndicatorModel.self)
            )
        case .storyIndicator:
            self = .storyIndicator(
                try singleValueContainer.decode(StoryIndicatorModel.self)
            )
        case .pagerController:
            self = .pagerController(
                try singleValueContainer.decode(PagerControllerModel.self)
            )
        case .formController:
            self = .formController(
                try singleValueContainer.decode(FormControllerModel.self)
            )
        case .checkbox:
            self = .checkbox(
                try singleValueContainer.decode(CheckboxModel.self)
            )
        case .checkboxController:
            self = .checkboxController(
                try singleValueContainer.decode(CheckboxControllerModel.self)
            )
        case .radioInput:
            self = .radioInput(
                try singleValueContainer.decode(RadioInputModel.self)
            )
        case .radioInputController:
            self = .radioInputController(
                try singleValueContainer.decode(RadioInputControllerModel.self)
            )
        case .textInput:
            self = .textInput(
                try singleValueContainer.decode(TextInputModel.self)
            )
        case .score:
            self = .score(try singleValueContainer.decode(ScoreModel.self))
        case .npsController:
            self = .npsController(
                try singleValueContainer.decode(NpsControllerModel.self)
            )
        case .toggle:
            self = .toggle(try singleValueContainer.decode(ToggleModel.self))
        case .stateController:
            self = .stateController(
                try singleValueContainer.decode(StateControllerModel.self)
            )
        case .customView:
            self = .customView(
                try singleValueContainer.decode(CustomViewModel.self)
            )
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        let content: Encodable
        
        switch self {
        case .container(let model):
            content = model
        case .linearLayout(let model):
            content = model
        #if !os(tvOS) && !os(watchOS)
        case .webView(let model):
            content = model
        #endif
        case .customView(let model):
            content = model
        case .scrollLayout(let model):
            content = model
        case .media(let model):
            content = model
        case .label(let model):
            content = model
        case .labelButton(let model):
            content = model
        case .imageButton(let model):
            content = model
        case .emptyView(let model):
            content = model
        case .pager(let model):
            content = model
        case .pagerIndicator(let model):
            content = model
        case .storyIndicator(let model):
            content = model
        case .pagerController(let model):
            content = model
        case .formController(let model):
            content = model
        case .checkbox(let model):
            content = model
        case .checkboxController(let model):
            content = model
        case .radioInput(let model):
            content = model
        case .radioInputController(let model):
            content = model
        case .textInput(let model):
            content = model
        case .score(let model):
            content = model
        case .npsController(let model):
            content = model
        case .toggle(let model):
            content = model
        case .stateController(let model):
            content = model
        }
        
        try container.encode(content)
    }
}

protocol BaseTextAppearance: Codable, Equatable, Sendable {
    var color: ThomasColor { get }
    var fontSize: Double { get }
    var alignment: TextAlignement? { get }
    var styles: [TextStyle]? { get }
    var fontFamilies: [String]? { get }
}

struct TextAppearance: BaseTextAppearance {
    var color: ThomasColor
    var fontSize: Double
    var alignment: TextAlignement?
    var styles: [TextStyle]?
    var fontFamilies: [String]?

    enum CodingKeys: String, CodingKey {
        case color = "color"
        case fontSize = "font_size"
        case alignment = "alignment"
        case styles = "styles"
        case fontFamilies = "font_families"
    }
}

protocol BaseModel: Codable, Equatable, Sendable {
    var type: ViewModelType { get }
    var border: Border? { get }
    var backgroundColor: ThomasColor? { get }
    var visibility: VisibilityInfo? { get }
    var eventHandlers: [EventHandler]? { get }
    var enableBehaviors: [EnableBehavior]? { get }
}

enum EventHandlerType: String, Codable, Equatable, Sendable {
    case tap
    case focus
    case formInput = "form_input"
}

struct EventHandler: Codable, Equatable, Sendable {
    let type: EventHandlerType
    let stateActions: [StateAction]

    enum CodingKeys: String, CodingKey {
        case type = "type"
        case stateActions = "state_actions"
    }
}

enum StateActionType: String, Codable, Equatable, Sendable {
    case setState = "set"
    case clearState = "clear"
    case formValue = "set_form_value"
}

enum StateAction: Codable, Equatable, Sendable {
    case setState(SetStateAction)
    case clearState
    case formValue(SetFormValueStateAction)

    enum CodingKeys: String, CodingKey {
        case type = "type"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(StateActionType.self, forKey: .type)
        let singleValueContainer = try decoder.singleValueContainer()

        switch type {
        case .setState:
            self = .setState(
                try singleValueContainer.decode(SetStateAction.self)
            )
        case .clearState:
            self = .clearState
        case .formValue:
            self = .formValue(
                try singleValueContainer.decode(SetFormValueStateAction.self)
            )
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var singleValue = encoder.singleValueContainer()
        
        switch self {
        case .setState(let action):
            try singleValue.encode(action)
        case .clearState:
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(StateActionType.clearState, forKey: .type)
        case .formValue(let action):
            try singleValue.encode(action)
        }
    }
}

struct SetStateAction: Codable, Equatable, Sendable {
    let type = StateActionType.setState
    let key: String
    let value: AirshipJSON?

    enum CodingKeys: String, CodingKey {
        case key = "key"
        case value = "value"
        case type
    }
}

struct SetFormValueStateAction: Codable, Equatable, Sendable {
    let type = StateActionType.formValue
    let key: String

    enum CodingKeys: String, CodingKey {
        case key = "key"
        case type
    }
}

struct VisibilityInfo: Codable, Equatable, Sendable {
    let invertWhenStateMatches: JSONPredicate
    let defaultVisibility: Bool

    enum CodingKeys: String, CodingKey {
        case statePredicate = "invert_when_state_matches"
        case defaultVisibility = "default"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let predicateJson = try container.decode(
            AirshipJSON.self,
            forKey: .statePredicate
        )

        self.defaultVisibility = try container.decode(
            Bool.self,
            forKey: .defaultVisibility
        )
        self.invertWhenStateMatches = try JSONPredicate(
            json: predicateJson.unWrap()
        )
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(defaultVisibility, forKey: .defaultVisibility)
        try container.encode(invertWhenStateMatches, forKey: .statePredicate)
    }
}

struct TextInputTextAppearance: BaseTextAppearance {
    var color: ThomasColor
    var fontSize: Double
    var alignment: TextAlignement?
    var styles: [TextStyle]?
    var fontFamilies: [String]?
    var placeHolderColor: ThomasColor?

    enum CodingKeys: String, CodingKey {
        case color = "color"
        case fontSize = "font_size"
        case alignment = "alignment"
        case styles = "styles"
        case fontFamilies = "font_families"
        case placeHolderColor = "place_holder_color"
    }
}

struct ContainerModel: BaseModel {
    let type = ViewModelType.container
    let border: Border?
    let backgroundColor: ThomasColor?
    let items: [ContainerItem]
    let visibility: VisibilityInfo?
    let eventHandlers: [EventHandler]?
    let enableBehaviors: [EnableBehavior]?

    enum CodingKeys: String, CodingKey {
        case border = "border"
        case backgroundColor = "background_color"
        case items = "items"
        case visibility = "visibility"
        case eventHandlers = "event_handlers"
        case enableBehaviors = "enabled"
        case type
    }
}

struct ContainerItem: Codable, Equatable, Sendable {
    let position: Position
    let margin: Margin?
    let size: Size
    let view: ViewModel
    let ignoreSafeArea: Bool?

    enum CodingKeys: String, CodingKey {
        case position = "position"
        case margin = "margin"
        case size = "size"
        case view = "view"
        case ignoreSafeArea = "ignore_safe_area"
    }
}

struct LinearLayoutModel: BaseModel {
    let type = ViewModelType.linearLayout
    let identifier: String?
    let border: Border?
    let backgroundColor: ThomasColor?
    let direction: Direction
    let items: [LinearLayoutItem]
    let ignoreSafeArea: Bool?
    let randomizeChildren: Bool?
    let visibility: VisibilityInfo?
    let eventHandlers: [EventHandler]?
    let enableBehaviors: [EnableBehavior]?

    enum CodingKeys: String, CodingKey {
        case items = "items"
        case identifier = "identifier"
        case border = "border"
        case backgroundColor = "background_color"
        case direction = "direction"
        case ignoreSafeArea = "ignore_safe_area"
        case randomizeChildren = "randomize_children"
        case visibility = "visibility"
        case eventHandlers = "event_handlers"
        case enableBehaviors = "enabled"
        case type
    }
}

struct LinearLayoutItem: Codable, Equatable, Sendable {
    let size: Size
    let margin: Margin?
    let view: ViewModel

    enum CodingKeys: String, CodingKey {
        case size = "size"
        case margin = "margin"
        case view = "view"
    }
}

struct ScrollLayoutModel: BaseModel {
    let type = ViewModelType.scrollLayout
    let border: Border?
    let backgroundColor: ThomasColor?
    let direction: Direction
    let view: ViewModel
    let visibility: VisibilityInfo?
    let eventHandlers: [EventHandler]?
    let enableBehaviors: [EnableBehavior]?

    enum CodingKeys: String, CodingKey {
        case border = "border"
        case backgroundColor = "background_color"
        case direction = "direction"
        case view = "view"
        case visibility = "visibility"
        case eventHandlers = "event_handlers"
        case enableBehaviors = "enabled"
        case type
    }
}

struct WebViewModel: BaseModel {
    let type = ViewModelType.webView
    let border: Border?
    let backgroundColor: ThomasColor?
    let url: String
    let visibility: VisibilityInfo?
    let eventHandlers: [EventHandler]?
    let enableBehaviors: [EnableBehavior]?

    enum CodingKeys: String, CodingKey {
        case border = "border"
        case backgroundColor = "background_color"
        case url = "url"
        case visibility = "visibility"
        case eventHandlers = "event_handlers"
        case enableBehaviors = "enabled"
        case type
    }
}

struct CustomViewModel: BaseModel {
    let name: String?
    let json: AirshipJSON?
    let height: CGFloat?
    let type = ViewModelType.customView
    let border: Border?
    let backgroundColor: ThomasColor?
    let visibility: VisibilityInfo?
    let eventHandlers: [EventHandler]?
    let enableBehaviors: [EnableBehavior]?

    enum CodingKeys: String, CodingKey {
        case name = "name"
        case json = "keys"
        case height = "height"
        case border = "border"
        case backgroundColor = "background_color"
        case visibility = "visibility"
        case eventHandlers = "event_handlers"
        case enableBehaviors = "enabled"
        case type
    }
}

struct MediaModel: BaseModel, Accessible, Codable {
    let type = ViewModelType.media
    let border: Border?
    let backgroundColor: ThomasColor?
    let url: String
    let mediaType: MediaType
    let mediaFit: MediaFit
    let contentDescription: String?
    let visibility: VisibilityInfo?
    let eventHandlers: [EventHandler]?
    let enableBehaviors: [EnableBehavior]?
    let video: Video?
    let cropPosition: Position?

    enum CodingKeys: String, CodingKey {
        case mediaType = "media_type"
        case url = "url"
        case border = "border"
        case backgroundColor = "background_color"
        case mediaFit = "media_fit"
        case contentDescription = "content_description"
        case visibility = "visibility"
        case eventHandlers = "event_handlers"
        case enableBehaviors = "enabled"
        case video = "video"
        case cropPosition = "position"
        case type
    }
}

struct Video: Codable, Equatable, Sendable {
    let aspectRatio: Double?
    let showControls: Bool?
    let autoplay: Bool?
    let muted: Bool?
    let loop: Bool?
    
    enum CodingKeys: String, CodingKey {
        case aspectRatio = "aspect_ratio"
        case showControls = "show_controls"
        case autoplay = "autoplay"
        case muted = "muted"
        case loop = "loop"
    }
}

struct LabelModel: BaseModel, Accessible, Codable {
    let type = ViewModelType.label
    let border: Border?
    let backgroundColor: ThomasColor?
    let text: String
    let textAppearance: TextAppearance
    let contentDescription: String?
    let visibility: VisibilityInfo?
    let eventHandlers: [EventHandler]?
    let enableBehaviors: [EnableBehavior]?

    enum CodingKeys: String, CodingKey {
        case text = "text"
        case textAppearance = "text_appearance"
        case border = "border"
        case backgroundColor = "background_color"
        case contentDescription = "content_description"
        case visibility = "visibility"
        case eventHandlers = "event_handlers"
        case enableBehaviors = "enabled"
        case type
    }
}

struct LabelButtonModel: BaseModel, Accessible, Codable {
    let type = ViewModelType.labelButton
    let identifier: String
    let border: Border?
    let backgroundColor: ThomasColor?
    let clickBehaviors: [ButtonClickBehavior]?
    let enableBehaviors: [EnableBehavior]?
    let actions: ActionsPayload?
    let label: LabelModel
    let contentDescription: String?
    let visibility: VisibilityInfo?
    let eventHandlers: [EventHandler]?
    let reportingMetadata: AirshipJSON?

    enum CodingKeys: String, CodingKey {
        case identifier = "identifier"
        case border = "border"
        case enableBehaviors = "enabled"
        case clickBehaviors = "button_click"
        case backgroundColor = "background_color"
        case actions = "actions"
        case label = "label"
        case contentDescription = "content_description"
        case visibility = "visibility"
        case eventHandlers = "event_handlers"
        case reportingMetadata = "reporting_metadata"
        case type
    }
}

enum ButtonImageModelType: String, Codable, Equatable, Sendable {
    case url
    case icon
}

enum ButtonImageModel: Codable, Equatable, Sendable {
    case url(ImageURLModel)
    case icon(IconModel)

    enum CodingKeys: String, CodingKey {
        case type = "type"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(
            ButtonImageModelType.self,
            forKey: .type
        )
        let singleValueContainer = try decoder.singleValueContainer()

        switch type {
        case .url:
            self = .url(try singleValueContainer.decode(ImageURLModel.self))
        case .icon:
            self = .icon(try singleValueContainer.decode(IconModel.self))
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        
        let content: Encodable
        switch self {
        case .icon(let model):
            content = model
        case .url(let model):
            content = model
        }
        
        try container.encode(content)
    }
}

struct ImageURLModel: Codable, Equatable, Sendable {
    let type = ButtonImageModelType.url
    let url: String

    enum CodingKeys: String, CodingKey {
        case url = "url"
        case type
    }
}

enum Icon: String, Codable, Equatable, Sendable {
    case close
    case checkmark
    case forwardArrow = "forward_arrow"
    case backArrow = "back_arrow"
}

struct IconModel: Codable, Equatable, Sendable {
    let type = ButtonImageModelType.icon
    let icon: Icon
    let color: ThomasColor
    let scale: Double?

    enum CodingKeys: String, CodingKey {
        case icon = "icon"
        case color = "color"
        case scale = "scale"
        case type
    }
}

struct ActionsPayload: Codable, Equatable, Sendable {
    let value: AirshipJSON

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let json = try container.decode(AirshipJSON.self)

        guard case .object(_) = json else {
            throw AirshipErrors.error("Invalid actions payload.")
        }
        self.value = json
    }
}

struct ImageButtonModel: BaseModel, Accessible, Codable {
    let type = ViewModelType.imageButton
    let identifier: String
    let border: Border?
    let backgroundColor: ThomasColor?
    let image: ButtonImageModel
    let clickBehaviors: [ButtonClickBehavior]?
    let enableBehaviors: [EnableBehavior]?
    let actions: ActionsPayload?
    let contentDescription: String?
    let visibility: VisibilityInfo?
    let eventHandlers: [EventHandler]?
    let reportingMetadata: AirshipJSON?

    enum CodingKeys: String, CodingKey {
        case identifier = "identifier"
        case border = "border"
        case backgroundColor = "background_color"
        case image = "image"
        case enableBehaviors = "enabled"
        case clickBehaviors = "button_click"
        case actions = "actions"
        case contentDescription = "content_description"
        case visibility = "visibility"
        case eventHandlers = "event_handlers"
        case reportingMetadata = "reporting_metadata"
        case type
    }
}

struct EmptyViewModel: BaseModel {
    let type = ViewModelType.emptyView
    let border: Border?
    let backgroundColor: ThomasColor?
    let visibility: VisibilityInfo?
    let eventHandlers: [EventHandler]?
    let enableBehaviors: [EnableBehavior]?

    enum CodingKeys: String, CodingKey {
        case border = "border"
        case backgroundColor = "background_color"
        case visibility = "visibility"
        case eventHandlers = "event_handlers"
        case enableBehaviors = "enabled"
        case type
    }
}

enum PagerGestureDirection: String, Codable, Equatable, Sendable {
    case up
    case down
}

enum PagerGestureLocation: String, Codable, Equatable, Sendable {
    case top
    case bottom
    case start
    case end
    case left
    case right
    case any
}

enum PagerGestureType: String, Codable, Equatable, Sendable {
    case tap
    case swipe
    case hold
}

protocol PagerGesture: Codable, Equatable, Sendable {
    var reportingMetadata: AirshipJSON? { get }
    var type: PagerGestureType { get }
    var identifier: String { get }
}

struct PagerDragGesture: PagerGesture {
    var type = PagerGestureType.swipe
    var identifier: String
    var reportingMetadata: AirshipJSON?
    let direction: PagerGestureDirection
    let behavior: PagerGestureBehavior
    
    enum CodingKeys: String, CodingKey {
        case identifier = "identifier"
        case reportingMetadata = "reporting_metadata"
        case direction = "direction"
        case behavior = "behavior"
        case type
    }
}

struct PagerTapGesture: PagerGesture {
    var type = PagerGestureType.tap
    var identifier: String
    var reportingMetadata: AirshipJSON?
    let location: PagerGestureLocation
    let behavior: PagerGestureBehavior
    
    enum CodingKeys: String, CodingKey {
        case identifier = "identifier"
        case location = "location"
        case behavior = "behavior"
        case type
    }
}

struct PagerHoldGesture: PagerGesture {
    var type = PagerGestureType.hold
    var identifier: String
    var reportingMetadata: AirshipJSON?
    let pressBehavior: PagerGestureBehavior
    let releaseBehavior: PagerGestureBehavior
    
    enum CodingKeys: String, CodingKey {
        case identifier = "identifier"
        case pressBehavior = "press_behavior"
        case releaseBehavior = "release_behavior"
        case type
    }
}

struct PagerGestureBehavior: Codable, Equatable, Sendable {
    let actions: [ActionsPayload]?
    let behaviors: [ButtonClickBehavior]?
    
    enum CodingKeys: String, CodingKey {
        case actions = "actions"
        case behaviors = "behaviors"
    }
}

struct PagerModel: BaseModel {
    let type = ViewModelType.pager
    let border: Border?
    let backgroundColor: ThomasColor?
    let disableSwipe: Bool?
    let items: [PagerItem]
    let visibility: VisibilityInfo?
    let eventHandlers: [EventHandler]?
    let enableBehaviors: [EnableBehavior]?
    let gestures: [PagerGestureModel]?

    enum CodingKeys: String, CodingKey {
        case border = "border"
        case backgroundColor = "background_color"
        case items = "items"
        case disableSwipe = "disable_swipe"
        case visibility = "visibility"
        case eventHandlers = "event_handlers"
        case enableBehaviors = "enabled"
        case gestures = "gestures"
        case type
    }
}

struct AutomatedAction: Codable, Equatable, Sendable {
    let identifier: String
    let delay: Double?
    let actions: [ActionsPayload]?
    let behaviors: [ButtonClickBehavior]?
    let reportingMetadata: AirshipJSON?
    
    enum CodingKeys: String, CodingKey {
        case identifier = "identifier"
        case delay = "delay"
        case actions = "actions"
        case behaviors = "behaviors"
        case reportingMetadata = "reporting_metadata"
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

struct PagerItem: Codable, Equatable, Sendable {
    let identifier: String
    let view: ViewModel
    let displayActions: ActionsPayload?
    let automatedActions: [AutomatedAction]?
    
    enum CodingKeys: String, CodingKey {
        case identifier = "identifier"
        case view = "view"
        case displayActions = "display_actions"
        case automatedActions = "automated_actions"
    }
}

struct PagerIndicatorModel: BaseModel {
    let type = ViewModelType.pagerIndicator
    let border: Border?
    let backgroundColor: ThomasColor?
    let bindings: Bindings
    let spacing: Double
    let visibility: VisibilityInfo?
    let eventHandlers: [EventHandler]?
    let enableBehaviors: [EnableBehavior]?

    enum CodingKeys: String, CodingKey {
        case border = "border"
        case backgroundColor = "background_color"
        case bindings = "bindings"
        case spacing = "spacing"
        case visibility = "visibility"
        case eventHandlers = "event_handlers"
        case enableBehaviors = "enabled"
        case type
    }

    struct Bindings: Codable, Equatable, Sendable {
        let selected: Binding
        let unselected: Binding

        enum CodingKeys: String, CodingKey {
            case selected = "selected"
            case unselected = "unselected"
        }
    }

    struct Binding: Codable, Equatable, Sendable {
        let shapes: [ShapeModel]?
        let icon: IconModel?

        enum CodingKeys: String, CodingKey {
            case shapes = "shapes"
            case icon = "icon"
        }
    }
}

struct StoryIndicatorModel: BaseModel {
    let type = ViewModelType.storyIndicator
    let border: Border?
    let backgroundColor: ThomasColor?
    let visibility: VisibilityInfo?
    let eventHandlers: [EventHandler]?
    let enableBehaviors: [EnableBehavior]?
    let source: StoryIndicatorSource
    let style: LinearProgressStoryIndicatorStyle

    enum CodingKeys: String, CodingKey {
        case border = "border"
        case backgroundColor = "background_color"
        case visibility = "visibility"
        case eventHandlers = "event_handlers"
        case enableBehaviors = "enabled"
        case source = "source"
        case style = "style"
        case type
    }
    
    struct StoryIndicatorSource: Codable, Equatable, Sendable {
        let type: IndicatorType
    }
    
    enum IndicatorType: String, Codable, Equatable, Sendable {
        case pager = "pager"
        case currentPage = "current_page"
    }
    
    enum LayoutDirection: String, Codable, Equatable, Sendable {
        case vertical = "vertical"
        case horizontal = "horizontal"
    }
    
    struct LinearProgressStoryIndicatorStyle: Codable, Equatable, Sendable {
        let type: ProgressType
        let direction: LayoutDirection
        let sizing: ProgressSizingType?
        let spacing: Double?
        let progressColor: ThomasColor
        let trackColor: ThomasColor
        
        enum CodingKeys: String, CodingKey {
            case type = "type"
            case direction = "direction"
            case sizing = "sizing"
            case spacing = "spacing"
            case progressColor = "progress_color"
            case trackColor = "track_color"
        }
    }
    
    enum ProgressSizingType: String, Codable, Equatable, Sendable {
        case equal = "equal"
        case pageDuration = "page_duration"
    }
    
    enum ProgressType: String, Codable, Equatable, Sendable {
        case linearProgress = "linear_progress"
    }
}

struct PagerControllerModel: BaseModel {
    let type = ViewModelType.pagerController
    let border: Border?
    let backgroundColor: ThomasColor?
    let view: ViewModel
    let identifier: String
    let visibility: VisibilityInfo?
    let eventHandlers: [EventHandler]?
    let enableBehaviors: [EnableBehavior]?

    enum CodingKeys: String, CodingKey {
        case border = "border"
        case backgroundColor = "background_color"
        case view = "view"
        case identifier = "identifier"
        case visibility = "visibility"
        case eventHandlers = "event_handlers"
        case enableBehaviors = "enabled"
        case type
    }

    static func == (lhs: PagerControllerModel, rhs: PagerControllerModel)
        -> Bool
    {
        return lhs.type == rhs.type
    }
}

struct FormControllerModel: BaseModel {
    let type = ViewModelType.formController
    let identifier: String
    let submit: FormSubmitBehavior?
    let border: Border?
    let backgroundColor: ThomasColor?
    let view: ViewModel
    let responseType: String?
    let enableBehaviors: [EnableBehavior]?
    let visibility: VisibilityInfo?
    let eventHandlers: [EventHandler]?
    let formEnableBehaviors: [EnableBehavior]?

    enum CodingKeys: String, CodingKey {
        case identifier = "identifier"
        case submit = "submit"
        case border = "border"
        case backgroundColor = "background_color"
        case view = "view"
        case responseType = "response_type"
        case visibility = "visibility"
        case eventHandlers = "event_handlers"
        case enableBehaviors = "enabled"
        case formEnableBehaviors = "form_enabled"
        case type
    }
}

struct StateControllerModel: BaseModel {
    let type = ViewModelType.stateController
    let border: Border?
    let backgroundColor: ThomasColor?
    let view: ViewModel
    let visibility: VisibilityInfo?
    let eventHandlers: [EventHandler]?
    let enableBehaviors: [EnableBehavior]?

    enum CodingKeys: String, CodingKey {
        case border = "border"
        case backgroundColor = "background_color"
        case view = "view"
        case visibility = "visibility"
        case eventHandlers = "event_handlers"
        case enableBehaviors = "enabled"
        case type
    }
}

struct NpsControllerModel: BaseModel {
    let type = ViewModelType.npsController
    let identifier: String
    let submit: FormSubmitBehavior?
    let border: Border?
    let backgroundColor: ThomasColor?
    let npsIdentifier: String
    let view: ViewModel
    let responseType: String?
    let enableBehaviors: [EnableBehavior]?
    let visibility: VisibilityInfo?
    let eventHandlers: [EventHandler]?
    let formEnableBehaviors: [EnableBehavior]?

    enum CodingKeys: String, CodingKey {
        case identifier = "identifier"
        case submit = "submit"
        case border = "border"
        case backgroundColor = "background_color"
        case view = "view"
        case npsIdentifier = "nps_identifier"
        case responseType = "response_type"
        case enableBehaviors = "enabled"
        case visibility = "visibility"
        case eventHandlers = "event_handlers"
        case formEnableBehaviors = "form_enabled"
        case type
    }
}

struct CheckboxControllerModel: BaseModel, Accessible {
    let type = ViewModelType.checkboxController
    let identifier: String
    let border: Border?
    let backgroundColor: ThomasColor?
    let isRequired: Bool?
    let minSelection: Int?
    let maxSelection: Int?
    let view: ViewModel
    let contentDescription: String?
    let enableBehaviors: [EnableBehavior]?
    let visibility: VisibilityInfo?
    let eventHandlers: [EventHandler]?

    enum CodingKeys: String, CodingKey {
        case identifier = "identifier"
        case border = "border"
        case backgroundColor = "background_color"
        case view = "view"
        case isRequired = "required"
        case minSelection = "min_selection"
        case maxSelection = "max_selection"
        case contentDescription = "content_description"
        case enableBehaviors = "enabled"
        case visibility = "visibility"
        case eventHandlers = "event_handlers"
        case type
    }
}

struct RadioInputControllerModel: BaseModel, Accessible {
    let type = ViewModelType.radioInputController
    let identifier: String
    let submit: FormSubmitBehavior?
    let border: Border?
    let backgroundColor: ThomasColor?
    let isRequired: Bool?
    let view: ViewModel
    let contentDescription: String?
    let attributeName: AttributeName?
    let enableBehaviors: [EnableBehavior]?
    let visibility: VisibilityInfo?
    let eventHandlers: [EventHandler]?

    enum CodingKeys: String, CodingKey {
        case identifier = "identifier"
        case submit = "submit"
        case border = "border"
        case backgroundColor = "background_color"
        case view = "view"
        case isRequired = "required"
        case contentDescription = "content_description"
        case attributeName = "attribute_name"
        case enableBehaviors = "enabled"
        case visibility = "visibility"
        case eventHandlers = "event_handlers"
        case type
    }
}

protocol Accessible {
    var contentDescription: String? { get }
}

struct TextInputModel: BaseModel, Accessible, Codable {
    let type = ViewModelType.textInput
    let border: Border?
    let backgroundColor: ThomasColor?
    let identifier: String
    let contentDescription: String?
    let isRequired: Bool?
    let placeHolder: String?
    let textAppearance: TextInputTextAppearance
    let enableBehaviors: [EnableBehavior]?
    let visibility: VisibilityInfo?
    let eventHandlers: [EventHandler]?
    let inputType: TextInputType

    enum CodingKeys: String, CodingKey {
        case textAppearance = "text_appearance"
        case border = "border"
        case backgroundColor = "background_color"
        case identifier = "identifier"
        case contentDescription = "content_description"
        case isRequired = "required"
        case placeHolder = "place_holder"
        case enableBehaviors = "enabled"
        case visibility = "visibility"
        case eventHandlers = "event_handlers"
        case inputType = "input_type"
        case type
    }
}

struct ToggleModel: BaseModel, Accessible, Codable {
    let type = ViewModelType.toggle
    let border: Border?
    let backgroundColor: ThomasColor?
    let identifier: String
    let contentDescription: String?
    let isRequired: Bool?
    let style: ToggleStyleModel
    let attributeName: AttributeName?
    let attributeValue: AttributeValue?
    let enableBehaviors: [EnableBehavior]?
    let visibility: VisibilityInfo?
    let eventHandlers: [EventHandler]?

    enum CodingKeys: String, CodingKey {
        case border = "border"
        case backgroundColor = "background_color"
        case identifier = "identifier"
        case contentDescription = "content_description"
        case isRequired = "required"
        case style = "style"
        case attributeName = "attribute_name"
        case attributeValue = "attribute_value"
        case enableBehaviors = "enabled"
        case visibility = "visibility"
        case eventHandlers = "event_handlers"
        case type
    }
}

struct CheckboxModel: BaseModel, Accessible, Codable {
    let type = ViewModelType.checkbox
    let border: Border?
    let backgroundColor: ThomasColor?
    let contentDescription: String?
    let value: String
    let style: ToggleStyleModel
    let visibility: VisibilityInfo?
    let eventHandlers: [EventHandler]?
    let enableBehaviors: [EnableBehavior]?

    enum CodingKeys: String, CodingKey {
        case border = "border"
        case backgroundColor = "background_color"
        case contentDescription = "content_description"
        case value = "reporting_value"
        case style = "style"
        case visibility = "visibility"
        case eventHandlers = "event_handlers"
        case enableBehaviors = "enabled"
        case type

    }
}

struct RadioInputModel: BaseModel, Accessible, Codable {
    let type = ViewModelType.radioInput
    let border: Border?
    let backgroundColor: ThomasColor?
    let contentDescription: String?
    let value: String
    let style: ToggleStyleModel
    let attributeValue: AttributeValue?
    let visibility: VisibilityInfo?
    let eventHandlers: [EventHandler]?
    let enableBehaviors: [EnableBehavior]?

    enum CodingKeys: String, CodingKey {
        case style = "style"
        case border = "border"
        case backgroundColor = "background_color"
        case contentDescription = "content_description"
        case value = "reporting_value"
        case attributeValue = "attribute_value"
        case visibility = "visibility"
        case eventHandlers = "event_handlers"
        case enableBehaviors = "enabled"
        case type
    }
}

enum ScoreStyleModelType: String, Codable, Equatable, Sendable {
    case numberRange = "number_range"
}

enum ScoreStyleModel: Codable, Equatable, Sendable {
    case numberRange(ScoreNumberRangeStyle)

    enum CodingKeys: String, CodingKey {
        case type = "type"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(ScoreStyleModelType.self, forKey: .type)
        let singleValueContainer = try decoder.singleValueContainer()

        switch type {
        case .numberRange:
            self = .numberRange(
                try singleValueContainer.decode(ScoreNumberRangeStyle.self)
            )
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        let content: Encodable
        switch self {
        case .numberRange(let model):
            content = model
        }
        
        try container.encode(content)
    }

}

struct ScoreNumberRangeStyle: Codable, Equatable, Sendable {
    let type = ScoreStyleModelType.numberRange
    let spacing: Double?
    let bindings: Bindings
    let start: Int
    let end: Int

    enum CodingKeys: String, CodingKey {
        case spacing = "spacing"
        case bindings = "bindings"
        case start = "start"
        case end = "end"
        case type
    }

    struct Bindings: Codable, Equatable, Sendable {
        let selected: Binding
        let unselected: Binding

        enum CodingKeys: String, CodingKey {
            case selected = "selected"
            case unselected = "unselected"
        }
    }

    struct Binding: Codable, Equatable, Sendable {
        let shapes: [ShapeModel]?
        let textAppearance: TextAppearance?

        enum CodingKeys: String, CodingKey {
            case shapes = "shapes"
            case textAppearance = "text_appearance"
        }
    }
}

struct ScoreModel: BaseModel, Accessible, Codable {
    let type = ViewModelType.score
    let border: Border?
    let backgroundColor: ThomasColor?
    let identifier: String
    let contentDescription: String?
    let isRequired: Bool?
    let style: ScoreStyleModel
    let attributeName: AttributeName?
    let enableBehaviors: [EnableBehavior]?
    let visibility: VisibilityInfo?
    let eventHandlers: [EventHandler]?

    enum CodingKeys: String, CodingKey {
        case border = "border"
        case backgroundColor = "background_color"
        case identifier = "identifier"
        case contentDescription = "content_description"
        case isRequired = "required"
        case style = "style"
        case attributeName = "attribute_name"
        case enableBehaviors = "enabled"
        case visibility = "visibility"
        case eventHandlers = "event_handlers"
        case type
    }
}

struct SwitchToggleStyleModel: Codable, Equatable, Sendable {
    let type = ToggleStyleModelType.switchStyle
    let colors: ToggleColors

    enum CodingKeys: String, CodingKey {
        case colors = "toggle_colors"
        case type
    }

    struct ToggleColors: Codable, Equatable, Sendable {
        var on: ThomasColor
        var off: ThomasColor

        enum CodingKeys: String, CodingKey {
            case on = "on"
            case off = "off"
        }
    }
}

struct CheckboxToggleStyleModel: Codable, Equatable, Sendable {
    let type = ToggleStyleModelType.checkboxStyle
    let bindings: Bindings

    enum CodingKeys: String, CodingKey {
        case bindings = "bindings"
        case type
    }

    struct Bindings: Codable, Equatable, Sendable {
        let selected: Binding
        let unselected: Binding

        enum CodingKeys: String, CodingKey {
            case selected = "selected"
            case unselected = "unselected"
        }
    }

    struct Binding: Codable, Equatable, Sendable {
        let shapes: [ShapeModel]?
        let icon: IconModel?

        enum CodingKeys: String, CodingKey {
            case shapes = "shapes"
            case icon = "icon"
        }
    }
}

enum ShapeModel: Codable, Equatable, Sendable {
    case rectangle(RectangleShapeModel)
    case ellipse(EllipseShapeModel)

    enum CodingKeys: String, CodingKey {
        case type = "type"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(ShapeModelType.self, forKey: .type)
        let singleValueContainer = try decoder.singleValueContainer()

        switch type {
        case .ellipse:
            self = .ellipse(
                try singleValueContainer.decode(EllipseShapeModel.self)
            )
        case .rectangle:
            self = .rectangle(
                try singleValueContainer.decode(RectangleShapeModel.self)
            )
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        
        let content: Encodable
        
        switch self {
        case .ellipse(let model):
            content = model
        case .rectangle(let model):
            content = model
        }
        
        try container.encode(content)
    }
    
}

struct EllipseShapeModel: Codable, Equatable, Sendable {
    let type = ShapeModelType.ellipse
    let border: Border?
    let scale: Double?
    let color: ThomasColor?
    let aspectRatio: Double?

    enum CodingKeys: String, CodingKey {
        case border = "border"
        case color = "color"
        case scale = "scale"
        case aspectRatio = "aspect_ratio"
        case type
    }
}

struct RectangleShapeModel: Codable, Equatable, Sendable {
    let type = ShapeModelType.rectangle
    let border: Border?
    let scale: Double?
    let color: ThomasColor?
    let aspectRatio: Double?

    enum CodingKeys: String, CodingKey {
        case border = "border"
        case color = "color"
        case scale = "scale"
        case aspectRatio = "aspect_ratio"
        case type
    }
}

struct Size: Codable, Equatable, Sendable {
    let width: SizeConstraint
    let height: SizeConstraint

    enum CodingKeys: String, CodingKey {
        case width = "width"
        case height = "height"
    }
}

struct ConstrainedSize: Codable, Equatable, Sendable {
    var minWidth: SizeConstraint?
    var width: SizeConstraint
    var maxWidth: SizeConstraint?
    var minHeight: SizeConstraint?
    var height: SizeConstraint
    var maxHeight: SizeConstraint?

    enum CodingKeys: String, CodingKey {
        case minWidth = "min_width"
        case width = "width"
        case maxWidth = "max_width"
        case minHeight = "min_height"
        case height = "height"
        case maxHeight = "max_height"
    }
}

struct AttributeName: Codable, Equatable, Hashable {
    let channel: String?
    let contact: String?

    enum CodingKeys: String, CodingKey {
        case channel = "channel"
        case contact = "contact"
    }
}

enum SizeConstraint: Codable, Equatable, Sendable {
    case points(Double)
    case percent(Double)
    case auto

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let sizeString = try? container.decode(String.self) {
            if sizeString == "auto" {
                self = .auto
            } else if sizeString.last == "%" {
                var perecent = sizeString
                perecent.removeLast()
                self = .percent(Double(perecent) ?? 0)
            } else {
                throw AirshipErrors.parseError("invalid size: \(sizeString)")
            }
        } else if let double = try? container.decode(Double.self) {
            self = .points(double)
        } else {
            throw AirshipErrors.parseError("invalid size")
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .auto:
            try container.encode("auto")
        case .percent(let value):
            try container.encode(String(format: "%.0f%%", value))
        case .points(let value):
            try container.encode(value)
        }
    }

    static func == (lhs: SizeConstraint, rhs: SizeConstraint) -> Bool {
        switch (lhs, rhs) {
        case (.auto, .auto):
            return true
        case (.points(let lh), .points(let rh)):
            return lh == rh
        case (.percent(let lh), .percent(let rh)):
            return lh == rh
        default:
            return false
        }
    }
}

struct Border: Codable, Equatable, Sendable {
    var radius: Double?
    var strokeWidth: Double?
    var strokeColor: ThomasColor?

    enum CodingKeys: String, CodingKey {
        case radius = "radius"
        case strokeWidth = "stroke_width"
        case strokeColor = "stroke_color"
    }
}

struct Margin: Codable, Equatable, Sendable {
    let top: CGFloat?
    let bottom: CGFloat?
    let start: CGFloat?
    let end: CGFloat?

    enum CodingKeys: String, CodingKey {
        case top = "top"
        case bottom = "bottom"
        case start = "start"
        case end = "end"
    }
}

enum BannerPosition: String, Codable, Equatable, Sendable {
    case top
    case bottom
}

struct Position: Codable, Equatable, Sendable {
    let horizontal: HorizontalPosition
    let vertical: VerticalPosition

    enum CodingKeys: String, CodingKey {
        case horizontal = "horizontal"
        case vertical = "vertical"
    }
}

enum Direction: String, Codable, Equatable, Sendable {
    case vertical = "vertical"
    case horizontal = "horizontal"
}

enum HorizontalPosition: String, Codable, Equatable, Sendable {
    case center = "center"
    case start = "start"
    case end = "end"
}

enum VerticalPosition: String, Codable, Equatable, Sendable {
    case center = "center"
    case top = "top"
    case bottom = "bottom"
}

enum MediaType: String, Codable, Equatable, Sendable {
    case image = "image"
    case video = "video"
    case youtube = "youtube"
}

enum MediaFit: String, Codable, Equatable, Sendable {
    @available(*, deprecated, message: "Use fit_crop + position instead")
    case center = "center"
    case fitCrop = "fit_crop"
    case centerInside = "center_inside"
    @available(*, deprecated, message: "Use fit_crop + position instead")
    case centerCrop = "center_crop"
}

enum TextAlignement: String, Codable, Equatable, Sendable {
    case start = "start"
    case end = "end"
    case center = "center"
}

enum TextInputType: String, Codable, Equatable, Sendable {
    case email = "email"
    case number = "number"
    case text = "text"
    case textMultiline = "text_multiline"
}

enum TextStyle: String, Codable, Equatable, Sendable {
    case bold = "bold"
    case italic = "italic"
    case underlined = "underlined"
}

enum EnableBehavior: String, Codable, Equatable, Sendable {
    case formValidation = "form_validation"
    case formSubmission = "form_submission"
    case pagerNext = "pager_next"
    case pagerPrevious = "pager_previous"
}

enum ButtonClickBehavior: String, Codable, Equatable, Sendable {
    case dismiss = "dismiss"
    case cancel = "cancel"
    case pagerNext = "pager_next"
    case pagerPrevious = "pager_previous"
    case pagerNextOrDismiss = "pager_next_or_dismiss"
    case pagerNextOrFirst = "pager_next_or_first"
    case formSubmit = "form_submit"
    case pagerPause = "pager_pause"
    case pagerResume = "pager_resume"
}

enum FormSubmitBehavior: String, Codable, Equatable, Sendable {
    case submitEvent = "submit_event"
}

enum ThomasPlatform: String, Codable, Equatable, Sendable {
    case android
    case ios
    case web
}

struct ColorSelector: Codable, Equatable, Sendable {
    let darkMode: Bool?
    let platform: ThomasPlatform?
    let color: HexColor

    enum CodingKeys: String, CodingKey {
        case platform = "platform"
        case darkMode = "dark_mode"
        case color = "color"
    }
}

struct ThomasColor: Codable, Equatable, Sendable {
    let defaultColor: HexColor
    let selectors: [ColorSelector]?

    enum CodingKeys: String, CodingKey {
        case defaultColor = "default"
        case selectors = "selectors"
    }
}

struct HexColor: Codable, Equatable, Sendable {
    let hex: String
    let alpha: Double?

    enum CodingKeys: String, CodingKey {
        case hex = "hex"
        case alpha = "alpha"
    }
}

enum AttributeValue: Codable, Equatable, Hashable, Sendable {
    case string(String)
    case number(Double)

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if let string = try? container.decode(String.self) {
            self = .string(string)
        } else if let number = try? container.decode(Double.self) {
            self = .number(number)
        } else {
            throw AirshipErrors.error("Invalid attribute value")
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        
        switch self {
        case .string(let value):
            try container.encode(value)
        case .number(let value):
            try container.encode(value)
        }
    }
}
