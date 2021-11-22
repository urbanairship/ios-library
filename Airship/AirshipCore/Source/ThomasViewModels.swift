/* Copyright Airship and Contributors */

import Foundation

struct Layout: Decodable, Equatable {
    let view: ViewModel
    let version: Int
    let presentation: PresentationModel
    let context: LayoutContext?

    enum CodingKeys: String, CodingKey {
        case view = "view"
        case version = "version"
        case presentation = "presentation"
        case context = "context"
    }
    
    
}

struct LayoutContext: Decodable, Equatable {
    let contentTypes: [String]
    
    enum CodingKeys: String, CodingKey {
        case contentTypes = "content_types"
    }
}

enum PresentationModelType : String, Decodable, Equatable {
    case modal
    case banner
}

enum PresentationModel : Decodable, Equatable {
    case banner(BannerPresentationModel)
    case modal(ModalPresentationModel)
    
    enum CodingKeys: String, CodingKey {
        case type = "type"
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(PresentationModelType.self, forKey: .type)
        let singleValueContainer = try decoder.singleValueContainer()

        switch type {
        case .banner:
            self = .banner(try singleValueContainer.decode(BannerPresentationModel.self))
        case .modal:
            self = .modal(try singleValueContainer.decode(ModalPresentationModel.self))
        }
    }
}

struct BannerPresentationModel : Decodable, Equatable {
    let duration: Int?
    let placementSelectors: [BannerPlacementSelector]?
    let defaultPlacement: BannerPlacement

    enum CodingKeys : String, CodingKey {
        case duration = "duration_milliseconds"
        case placementSelectors = "placement_selectors"
        case defaultPlacement = "default_placement"
    }
}

struct BannerPlacement : Decodable, Equatable {
    let margin: Margin?
    let size: Size
    let position: BannerPosition
    
    enum CodingKeys: String, CodingKey {
        case margin = "margin"
        case size = "size"
        case position = "position"
    }
}

struct BannerPlacementSelector : Decodable, Equatable {
    let placement: BannerPlacement
    let windowSize: WindowSize?
    let orientation: Orientation?
    
    enum CodingKeys : String, CodingKey {
        case placement = "placement"
        case windowSize = "windowSize"
        case orientation = "orientation"
    }
}

struct ModalPresentationModel: Decodable, Equatable {
    let placementSelectors: [ModalPlacementSelector]?
    let defaultPlacement: ModalPlacement
    let dismissOnTouchOutside: Bool?

    enum CodingKeys: String, CodingKey {
        case placementSelectors = "placement_selectors"
        case defaultPlacement = "default_placement"
        case dismissOnTouchOutside = "dismiss_on_touch_outside"
    }
}

struct ModalPlacement : Decodable, Equatable {
    let margin: Margin?
    let size: Size
    let position: Position?
    let shade: ThomasColor?
    
    enum CodingKeys: String, CodingKey {
        case margin = "margin"
        case size = "size"
        case position = "position"
        case shade = "shade_color"
    }
}

struct ModalPlacementSelector : Decodable, Equatable {
    let placement: ModalPlacement
    let windowSize: WindowSize?
    let orientation: Orientation?
    
    enum CodingKeys : String, CodingKey {
        case placement = "placement"
        case windowSize = "windowSize"
        case orientation = "orientation"
    }
}

enum WindowSize : String, Decodable, Equatable {
    case small = "small"
    case medium = "medium"
    case large = "large"
}

enum Orientation : String, Decodable, Equatable {
    case portrait = "portrait"
    case landscape = "landscape"
}

enum ShapeModelType: String, Decodable, Equatable {
    case rectangle = "rectangle"
    case ellipse = "ellipse"
}

enum ToggleStyleModelType: String, Decodable, Equatable {
    case switchStyle = "switch"
    case checkboxStyle = "checkbox"
}

enum ToggleStyleModel: Decodable, Equatable {
    case switchStyle(SwitchToggleStyleModel)
    case checkboxStyle(CheckboxToggleStyleModel)
    
    enum CodingKeys: String, CodingKey {
        case type = "type"
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(ToggleStyleModelType.self, forKey: .type)
        let singleValueContainer = try decoder.singleValueContainer()

        switch type {
        case .switchStyle:
            self = .switchStyle(try singleValueContainer.decode(SwitchToggleStyleModel.self))
        case .checkboxStyle:
            self = .checkboxStyle(try singleValueContainer.decode(CheckboxToggleStyleModel.self))
        }
    }
}

enum ViewModelType: String, Decodable {
    case container = "container"
    case linearLayout = "linear_layout"
    case webView = "web_view"
    case scrollLayout = "scroll_layout"
    case media = "media"
    case label = "label"
    case labelButton = "label_button"
    case imageButton = "image_button"
    case emptyView = "empty_view"
    case pager = "pager"
    case pagerIndicator = "pager_indicator"
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
}

indirect enum ViewModel: Decodable, Equatable {
    case container(ContainerModel)
    case linearLayout(LinearLayoutModel)
#if !os(tvOS)
    case webView(WebViewModel)
#endif
    case scrollLayout(ScrollLayoutModel)
    case media(MediaModel)
    case label(LabelModel)
    case labelButton(LabelButtonModel)
    case imageButton(ImageButtonModel)
    case emptyView(EmptyViewModel)
    case pager(PagerModel)
    case pagerIndicator(PagerIndicatorModel)
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
    
    private enum CodingKeys: String, CodingKey {
        case type
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(ViewModelType.self, forKey: .type)
        let singleValueContainer = try decoder.singleValueContainer()

        switch type {
        case .container:
            self = .container(try singleValueContainer.decode(ContainerModel.self))
        case .linearLayout:
            self = .linearLayout(try singleValueContainer.decode(LinearLayoutModel.self))

        case .webView:
#if os(tvOS)
            throw AirshipErrors.error("Webview not available on tvOS")
#else
            self = .webView(try singleValueContainer.decode(WebViewModel.self))
#endif
            
        case .scrollLayout:
            self = .scrollLayout(try singleValueContainer.decode(ScrollLayoutModel.self))
        case .media:
            self = .media(try singleValueContainer.decode(MediaModel.self))
        case .label:
            self = .label(try singleValueContainer.decode(LabelModel.self))
        case .labelButton:
            self = .labelButton(try singleValueContainer.decode(LabelButtonModel.self))
        case .imageButton:
            self = .imageButton(try singleValueContainer.decode(ImageButtonModel.self))
        case .emptyView:
            self = .emptyView(try singleValueContainer.decode(EmptyViewModel.self))
        case .pager:
            self = .pager(try singleValueContainer.decode(PagerModel.self))
        case .pagerIndicator:
            self = .pagerIndicator(try singleValueContainer.decode(PagerIndicatorModel.self))
        case .pagerController:
            self = .pagerController(try singleValueContainer.decode(PagerControllerModel.self))
        case .formController:
            self = .formController(try singleValueContainer.decode(FormControllerModel.self))
        case .checkbox:
            self = .checkbox(try singleValueContainer.decode(CheckboxModel.self))
        case .checkboxController:
            self = .checkboxController(try singleValueContainer.decode(CheckboxControllerModel.self))
        case .radioInput:
            self = .radioInput(try singleValueContainer.decode(RadioInputModel.self))
        case .radioInputController:
            self = .radioInputController(try singleValueContainer.decode(RadioInputControllerModel.self))
        case .textInput:
            self = .textInput(try singleValueContainer.decode(TextInputModel.self))
        case .score:
            self = .score(try singleValueContainer.decode(ScoreModel.self))
        case .npsController:
            self = .npsController(try singleValueContainer.decode(NpsControllerModel.self))
        case .toggle:
            self = .toggle(try singleValueContainer.decode(ToggleModel.self))
        }
    }
}

struct TextAppearanceModel : Decodable, Equatable {
    let color: ThomasColor
    let fontSize: Double
    let alignment: TextAlignement?
    let styles: [TextStyle]?
    let fontFamilies: [String]?
    
    enum CodingKeys : String, CodingKey {
        case color = "color"
        case fontSize = "font_size"
        case alignment = "alignment"
        case styles = "styles"
        case fontFamilies = "font_families"
    }
}

struct ContainerModel : Decodable, Equatable {
    let type = ViewModelType.container
    let border: Border?
    let backgroundColor: ThomasColor?
    let items: [ContainerItem]
    
    enum CodingKeys : String, CodingKey {
        case border = "border"
        case backgroundColor = "background_color"
        case items = "items"
    }
}

struct ContainerItem : Decodable, Equatable {
    let position: Position
    let margin: Margin?
    let size: Size
    let view: ViewModel
    
    enum CodingKeys: String, CodingKey {
        case position = "position"
        case margin = "margin"
        case size = "size"
        case view = "view"
    }
}

struct LinearLayoutModel: Decodable, Equatable {
    let type = ViewModelType.linearLayout
    let identifier: String?
    let border: Border?
    let backgroundColor: ThomasColor?
    let direction: Direction
    let items: [LinearLayoutItem]
    
    enum CodingKeys: String, CodingKey {
        case items = "items"
        case identifier = "identifier"
        case border = "border"
        case backgroundColor = "background_color"
        case direction = "direction"
    }
}

struct LinearLayoutItem: Decodable, Equatable {
    let size: Size
    let margin: Margin?
    let view: ViewModel

    enum CodingKeys: String, CodingKey {
        case size = "size"
        case margin = "margin"
        case view = "view"
    }
}

struct ScrollLayoutModel: Decodable, Equatable {
    let type = ViewModelType.scrollLayout
    let border: Border?
    let backgroundColor: ThomasColor?
    let direction: Direction
    let view: ViewModel

    enum CodingKeys: String, CodingKey {
        case border = "border"
        case backgroundColor = "background_color"
        case direction = "direction"
        case view = "view"
    }
}

struct WebViewModel: Decodable, Equatable {
    let type = ViewModelType.webView
    let border: Border?
    let backgroundColor: ThomasColor?
    let url: String
    
    enum CodingKeys: String, CodingKey {
        case border = "border"
        case backgroundColor = "background_color"
        case url = "url"
    }
}

struct MediaModel: Decodable, Equatable {
    let type = ViewModelType.media
    let border: Border?
    let backgroundColor: ThomasColor?
    let url: String
    let mediaType: MediaType
    
    enum CodingKeys: String, CodingKey {
        case mediaType = "media_type"
        case url = "url"
        case border = "border"
        case backgroundColor = "background_color"
    }
}

struct LabelModel: Decodable, Equatable {
    let type = ViewModelType.label
    let border: Border?
    let backgroundColor: ThomasColor?
    let text: String
    let textAppearance: TextAppearanceModel
    
    enum CodingKeys: String, CodingKey {
        case text = "text"
        case textAppearance = "text_appearance"
        case border = "border"
        case backgroundColor = "background_color"
    }
}

struct LabelButtonModel: Decodable, Equatable {
    let type = ViewModelType.labelButton
    let identifier: String
    let border: Border?
    let backgroundColor: ThomasColor?
    let clickBehaviors: [ButtonClickBehavior]?
    let enableBehaviors: [ButtonEnableBehavior]?
    let actions: ActionsPayload?
    let label: LabelModel
    let contentDescription: String?
    
    enum CodingKeys: String, CodingKey {
        case identifier = "identifier"
        case border = "border"
        case enableBehaviors = "enabled"
        case clickBehaviors = "button_click"
        case backgroundColor = "background_color"
        case actions = "actions"
        case label = "label"
        case contentDescription = "content_description"
    }
}

enum ButtonImageModelType: String, Decodable, Equatable {
    case url
    case icon
}

enum ButtomImageModel: Decodable, Equatable {
    case url(ImageURLModel)
    case icon(IconModel)
    
    enum CodingKeys: String, CodingKey {
        case type = "type"
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(ButtonImageModelType.self, forKey: .type)
        let singleValueContainer = try decoder.singleValueContainer()

        switch type {
        case .url:
            self = .url(try singleValueContainer.decode(ImageURLModel.self))
        case .icon:
            self = .icon(try singleValueContainer.decode(IconModel.self))
        }
    }
}

struct ImageURLModel: Decodable, Equatable {
    let url: String
    
    enum CodingKeys: String, CodingKey {
        case url = "url"
    }
}

enum Icon: String, Decodable, Equatable {
    case close
    case checkmark
    case leftArrow
    case rightArrow
}

struct IconModel: Decodable, Equatable {
    let icon: Icon
    let color: ThomasColor
    let scale: Double?
    
    enum CodingKeys: String, CodingKey {
        case icon = "icon"
        case color = "color"
        case scale = "scale"
    }
}

struct ActionsPayload: Decodable, Equatable {
    let value: [String: AnyHashable]
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let json = try container.decode(JSON.self).unWrap()
        guard let value = json as? [String: AnyHashable] else {
            throw AirshipErrors.error("Invalid actions payload.")
        }
        self.value = value
    }
}

struct ImageButtonModel: Decodable, Equatable {
    let type = ViewModelType.imageButton
    let identifier: String
    let border: Border?
    let backgroundColor: ThomasColor?
    let image: ButtomImageModel
    let clickBehaviors: [ButtonClickBehavior]?
    let enableBehaviors: [ButtonEnableBehavior]?
    let actions: ActionsPayload?
    let contentDescription: String?
    
    enum CodingKeys: String, CodingKey {
        case identifier = "identifier"
        case border = "border"
        case backgroundColor = "background_color"
        case image = "image"
        case enableBehaviors = "enabled"
        case clickBehaviors = "button_click"
        case actions = "actions"
        case contentDescription = "content_description"
    }
}

struct EmptyViewModel: Decodable, Equatable {
    let type = ViewModelType.emptyView
    let border: Border?
    let backgroundColor: ThomasColor?
    
    enum CodingKeys: String, CodingKey {
        case border = "border"
        case backgroundColor = "background_color"
    }
}

struct PagerModel: Decodable, Equatable {
    let type = ViewModelType.pager
    let border: Border?
    let backgroundColor: ThomasColor?
    let disableSwipe: Bool?
    let identifier: String
    let items: [ViewModel]
    
    enum CodingKeys: String, CodingKey {
        case border = "border"
        case backgroundColor = "background_color"
        case items = "items"
        case disableSwipe = "disable_swipe"
        case identifier = "identifier"
    }
}

struct PagerIndicatorModel: Decodable, Equatable {
    let type = ViewModelType.pagerIndicator
    let border: Border?
    let backgroundColor: ThomasColor?
    let bindings: Bindings
    let spacing: Double

    enum CodingKeys: String, CodingKey {
        case border = "border"
        case backgroundColor = "background_color"
        case bindings = "bindings"
        case spacing = "spacing"
    }
    
    struct Bindings: Decodable, Equatable {
        let selected: Binding
        let unselected: Binding

        enum CodingKeys: String, CodingKey {
            case selected = "selected"
            case unselected = "unselected"
        }
    }
    
    struct Binding: Decodable, Equatable {
        let shapes: [ShapeModel]?
        let icon: IconModel?

        enum CodingKeys: String, CodingKey {
            case shapes = "shapes"
            case icon = "icon"
        }
    }
}

struct PagerControllerModel: Decodable, Equatable {
    let type = ViewModelType.pagerController
    let border: Border?
    let backgroundColor: ThomasColor?
    let view: ViewModel

    enum CodingKeys: String, CodingKey {
        case border = "border"
        case backgroundColor = "background_color"
        case view = "view"
    }
    
    static func == (lhs: PagerControllerModel, rhs: PagerControllerModel) -> Bool {
        return lhs.type == rhs.type
    }
}

struct FormControllerModel: Decodable, Equatable {
    let type = ViewModelType.formController
    let identifier: String
    let submit: FormSubmitBehavior?
    let border: Border?
    let backgroundColor: ThomasColor?
    
    let view: ViewModel

    enum CodingKeys: String, CodingKey {
        case identifier = "identifier"
        case submit = "submit"
        case border = "border"
        case backgroundColor = "background_color"
        case view = "view"
    }
}

struct NpsControllerModel: Decodable, Equatable {
    let type = ViewModelType.formController
    let identifier: String
    let submit: FormSubmitBehavior?
    let border: Border?
    let backgroundColor: ThomasColor?
    let npsIdentifier: String
    let view: ViewModel

    enum CodingKeys: String, CodingKey {
        case identifier = "identifier"
        case submit = "submit"
        case border = "border"
        case backgroundColor = "background_color"
        case view = "view"
        case npsIdentifier = "nps_identifier"
    }
}

struct CheckboxControllerModel: Decodable, Equatable {
    let type = ViewModelType.checkboxController
    let identifier: String
    let border: Border?
    let backgroundColor: ThomasColor?
    let isRequired: Bool?
    let minSelection: Int?
    let maxSelection: Int?
    let view: ViewModel

    enum CodingKeys: String, CodingKey {
        case identifier = "identifier"
        case border = "border"
        case backgroundColor = "background_color"
        case view = "view"
        case isRequired = "required"
        case minSelection = "min_selection"
        case maxSelection = "max_selection"
    }
}

struct RadioInputControllerModel: Decodable, Equatable {
    let type = ViewModelType.radioInputController
    let identifier: String
    let submit: FormSubmitBehavior?
    let border: Border?
    let backgroundColor: ThomasColor?
    let isRequired: Bool?
    let view: ViewModel

    enum CodingKeys: String, CodingKey {
        case identifier = "identifier"
        case submit = "submit"
        case border = "border"
        case backgroundColor = "background_color"
        case view = "view"
        case isRequired = "required"
    }
}

struct TextInputModel: Decodable, Equatable {
    let type = ViewModelType.textInput
    let border: Border?
    let backgroundColor: ThomasColor?
    let identifier: String
    let contentDescription: String?
    let isRequired: Bool?
    let placeHolder: String?
    let textAppearance: TextAppearanceModel

    enum CodingKeys: String, CodingKey {
        case textAppearance = "text_appearance"
        case border = "border"
        case backgroundColor = "background_color"
        case identifier = "identifier"
        case contentDescription = "content_description"
        case isRequired = "required"
        case placeHolder = "place_holder"
    }
}

struct ToggleModel: Decodable, Equatable {
    let type = ViewModelType.toggle
    let border: Border?
    let backgroundColor: ThomasColor?
    let identifier: String
    let contentDescription: String?
    let isRequired: Bool?
    let style: ToggleStyleModel

    enum CodingKeys: String, CodingKey {
        case border = "border"
        case backgroundColor = "background_color"
        case identifier = "identifier"
        case contentDescription = "content_description"
        case isRequired = "required"
        case style = "style"
    }
}

struct CheckboxModel: Decodable, Equatable {
    let type = ViewModelType.checkbox
    let border: Border?
    let backgroundColor: ThomasColor?
    let contentDescription: String?
    let value: String
    let style: ToggleStyleModel

    enum CodingKeys: String, CodingKey {
        case border = "border"
        case backgroundColor = "background_color"
        case contentDescription = "content_description"
        case value = "value"
        case style = "style"
    }
}

struct RadioInputModel: Decodable, Equatable {
    let type = ViewModelType.radioInput
    let border: Border?
    let backgroundColor: ThomasColor?
    let contentDescription: String?
    let value: String
    let style: ToggleStyleModel
    
    enum CodingKeys: String, CodingKey {
        case style = "style"
        case border = "border"
        case backgroundColor = "background_color"
        case contentDescription = "content_description"
        case value = "value"
    }
}


enum ScoreStyleModelType: String, Decodable, Equatable {
    case npsStyle = "nps"
}

enum ScoreStyleModel: Decodable, Equatable {
    case nps(ScoreNPSStyleModel)
    
    enum CodingKeys: String, CodingKey {
        case type = "type"
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(ScoreStyleModelType.self, forKey: .type)
        let singleValueContainer = try decoder.singleValueContainer()

        switch type {
        case .npsStyle:
            self = .nps(try singleValueContainer.decode(ScoreNPSStyleModel.self))
        }
    }
    
}

struct ScoreNPSStyleModel: Decodable, Equatable {
    let type = ScoreStyleModelType.npsStyle
    let spacing: Double?
    let bindings: Bindings
    
    enum CodingKeys: String, CodingKey {
        case spacing = "spacing"
        case bindings = "bindings"
    }
    
    struct Bindings: Decodable, Equatable {
        let selected: Binding
        let unselected: Binding

        enum CodingKeys: String, CodingKey {
            case selected = "selected"
            case unselected = "unselected"
        }
    }
    
    struct Binding: Decodable, Equatable {
        let shapes: [ShapeModel]?
        let textAppearance: TextAppearanceModel?

        enum CodingKeys: String, CodingKey {
            case shapes = "shapes"
            case textAppearance = "text_appearance"
        }
    }
}

struct ScoreModel: Decodable, Equatable {
    let type = ViewModelType.score
    let border: Border?
    let backgroundColor: ThomasColor?
    let identifier: String
    let contentDescription: String?
    let isRequired: Bool?
    let style: ScoreStyleModel
    
    enum CodingKeys: String, CodingKey {
        case border = "border"
        case backgroundColor = "background_color"
        case identifier = "identifier"
        case contentDescription = "content_description"
        case isRequired = "required"
        case style = "style"
    }
}

struct SwitchToggleStyleModel: Decodable, Equatable {
    let colors: ToggleColors
    
    enum CodingKeys: String, CodingKey {
        case colors = "toggle_colors"
    }
    
    struct ToggleColors: Decodable, Equatable {
        var on: ThomasColor
        var off: ThomasColor

        enum CodingKeys: String, CodingKey {
            case on = "on"
            case off = "off"
        }
    }
}

struct CheckboxToggleStyleModel: Decodable, Equatable {
    let bindings: Bindings
    
    enum CodingKeys: String, CodingKey {
        case bindings = "bindings"
    }

    struct Bindings: Decodable, Equatable {
        let selected: Binding
        let unselected: Binding

        enum CodingKeys: String, CodingKey {
            case selected = "selected"
            case unselected = "unselected"
        }
    }
    
    struct Binding: Decodable, Equatable {
        let shapes: [ShapeModel]?
        let icon: IconModel?

        enum CodingKeys: String, CodingKey {
            case shapes = "shapes"
            case icon = "icon"
        }
    }
}

enum ShapeModel : Decodable, Equatable {
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
            self = .ellipse(try singleValueContainer.decode(EllipseShapeModel.self))
        case .rectangle:
            self = .rectangle(try singleValueContainer.decode(RectangleShapeModel.self))
        }
    }
}


struct EllipseShapeModel: Decodable, Equatable {
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
    }
}

struct RectangleShapeModel: Decodable, Equatable {
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
    }
}

struct Size: Decodable, Equatable {
    let width: SizeConstraint
    let height: SizeConstraint
    
    enum CodingKeys: String, CodingKey {
        case width = "width"
        case height = "height"
    }
}

enum SizeConstraint: Decodable, Equatable {
    case points(Double)
    case percent(Double)
    case auto

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let sizeString = try? container.decode(String.self) {
            if (sizeString == "auto") {
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

struct Border: Decodable, Equatable {
    var radius: Double?
    var strokeWidth: Double?
    var strokeColor: ThomasColor?
    
    enum CodingKeys: String, CodingKey {
        case radius = "radius"
        case strokeWidth = "stroke_width"
        case strokeColor = "stroke_color"
    }
}

struct Margin: Decodable, Equatable {
    let top: Double?
    let bottom: Double?
    let start: Double?
    let end: Double?
    
    enum CodingKeys: String, CodingKey {
        case top = "top"
        case bottom = "bottom"
        case start = "start"
        case end = "end"
    }
}

enum BannerPosition: String, Decodable, Equatable {
    case top
    case bottom
}

struct Position: Decodable, Equatable {
    let horizontal: HorizontalPosition
    let vertical: VerticalPosition
    
    enum CodingKeys: String, CodingKey {
        case horizontal = "horizontal"
        case vertical = "vertical"
    }
}

enum Direction: String, Decodable, Equatable {
    case vertical = "vertical"
    case horizontal = "horizontal"
}

enum HorizontalPosition: String, Decodable, Equatable {
    case center = "center"
    case start = "start"
    case end = "end"
}

enum VerticalPosition: String, Decodable, Equatable {
    case center = "center"
    case top = "top"
    case bottom = "bottom"
}

enum MediaType: String, Decodable, Equatable {
    case image = "image"
    case video = "video"
    case youtube = "youtube"
}

enum TextAlignement: String, Decodable, Equatable {
    case start = "start"
    case end = "end"
    case center = "center"
}

enum TextInputType: String, Decodable, Equatable {
    case email = "email"
    case number = "number"
    case text = "text"
    case textMultiline = "text_multiline"
}

enum TextStyle: String, Decodable, Equatable {
    case bold = "bold"
    case italic = "italic"
    case underlined = "underlined"
}

enum ButtonEnableBehavior: String, Decodable, Equatable {
    case formValidation = "form_validation"
    case pagerNext = "pager_next"
    case pagerPrevious = "pager_previous"
}

enum ButtonClickBehavior: String, Decodable, Equatable {
    case dismiss = "dismiss"
    case cancel = "cancel"
    case pagerNext = "pager_next"
    case pagerPrevious = "pager_previous"
    case formSubmit = "form_submit"
}

enum FormSubmitBehavior: String, Decodable, Equatable {
    case submitEvent = "submit_event"
}

enum ThomasPlatform: String, Decodable, Equatable {
    case android
    case ios
    case web
}

struct ColorSelector: Decodable, Equatable {
    let darkMode: Bool?
    let platform: ThomasPlatform?
    let color: HexColor
    
    enum CodingKeys: String, CodingKey {
        case platform = "platform"
        case darkMode = "dark_mode"
        case color = "color"
    }
}

struct ThomasColor: Decodable, Equatable {
    let defaultColor: HexColor
    let selectors: [ColorSelector]?
    
    enum CodingKeys: String, CodingKey {
        case defaultColor = "default"
        case selectors = "selectors"
    }
}

struct HexColor: Decodable, Equatable {
    let hex: String
    let alpha: Double?
    
    enum CodingKeys: String, CodingKey {
        case hex = "hex"
        case alpha = "alpha"
    }
}

enum JSON: Decodable {
    case string(String)
    case number(Double)
    case object([String:JSON])
    case array([JSON])
    case bool(Bool)
    case null
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if let object = try? container.decode([String: JSON].self) {
            self = .object(object)
        } else if let array = try? container.decode([JSON].self) {
            self = .array(array)
        } else if let string = try? container.decode(String.self) {
            self = .string(string)
        } else if let bool = try? container.decode(Bool.self) {
            self = .bool(bool)
        } else if let number = try? container.decode(Double.self) {
            self = .number(number)
        } else if container.decodeNil() {
            self = .null
        } else {
            throw AirshipErrors.error("Invalid JSON")
        }
    }
    
    func unWrap() -> Any? {
        switch (self) {
        case .string(let value):
            return value
        case .number(let value):
            return value
        case .bool(let value):
            return value
        case .null:
            return nil
        case .object(let value):
            var dict: [String: Any] = [:]
            value.forEach {
                dict[$0.key] = $0.value.unWrap()
            }
            return dict
        case .array(let value):
            var array: [Any] = []
            value.forEach {
                if let item = $0.unWrap() {
                    array.append(item)
                }
            }
            return array
        }
       
    }
}
