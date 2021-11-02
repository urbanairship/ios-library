/* Copyright Airship and Contributors */

import Foundation

class Layout: Decodable {
    private let _layout: BaseViewModelWrapper
    lazy var layout: BaseViewModel = {
        return _layout.view
    }()

    enum CodingKeys: String, CodingKey {
        case _layout = "layout"
    }
}

struct LayoutDecoder  {
    private static let decoder = JSONDecoder()
    
    static func decode(_ json: Data) throws -> Layout {
        do {
        return try self.decoder.decode(Layout.self, from: json)
        } catch {
            print(error)
            throw error
        }
    }
}

enum ShapeType: String, Decodable {
    case rectangle = "rectangle"
    case circle = "circle"
}


enum ToggleStyleType: String, Decodable {
    case switchStyle = "switch"
    case checkboxStyle = "checkbox"
}

enum ViewType: String, Decodable {
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
    case npsController = "nps_controller"
    case toggle = "toggle"
}

protocol BaseViewModel: Decodable {
    var type: ViewType { get }
    var border: Border? { get }
    var backgroundColor: HexColor? { get }
}

protocol ButtonModel: BaseViewModel {
    var clickBehaviors: [ButtonClickBehavior]? { get }
    var enableBehaviors: [ButtonEnableBehavior]? { get }
    var actions: [String]? { get }
}

private struct BaseViewModelWrapper : Decodable {
    let view: BaseViewModel

    private enum CodingKeys: String, CodingKey {
        case type
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(ViewType.self, forKey: .type)
        let singleValueContainer = try decoder.singleValueContainer()

        switch type {
        case .container:
            self.view = try singleValueContainer.decode(ContainerModel.self)
        case .linearLayout:
            self.view = try singleValueContainer.decode(LinearLayoutModel.self)
        case .webView:
            self.view = try singleValueContainer.decode(WebViewModel.self)
        case .scrollLayout:
            self.view = try singleValueContainer.decode(ScrollLayoutModel.self)
        case .media:
            self.view = try singleValueContainer.decode(MediaModel.self)
        case .label:
            self.view = try singleValueContainer.decode(LabelModel.self)
        case .labelButton:
            self.view = try singleValueContainer.decode(LabelButtonModel.self)
        case .imageButton:
            self.view = try singleValueContainer.decode(ImageButtonModel.self)
        case .emptyView:
            self.view = try singleValueContainer.decode(EmptyViewModel.self)
        case .pager:
            self.view = try singleValueContainer.decode(PagerModel.self)
        case .pagerIndicator:
            self.view = try singleValueContainer.decode(PagerIndicatorModel.self)
        case .pagerController:
            self.view = try singleValueContainer.decode(PagerControllerModel.self)
        case .formController:
            self.view = try singleValueContainer.decode(FormControllerModel.self)
        case .checkbox:
            self.view = try singleValueContainer.decode(CheckboxModel.self)
        case .checkboxController:
            self.view = try singleValueContainer.decode(CheckboxControllerModel.self)
        case .radioInput:
            self.view = try singleValueContainer.decode(RadioInputModel.self)
        case .radioInputController:
            self.view = try singleValueContainer.decode(RadioInputControllerModel.self)
        case .textInput:
            self.view = try singleValueContainer.decode(TextInputModel.self)
        case .score:
            self.view = try singleValueContainer.decode(ScoreModel.self)
        case .npsController:
            self.view = try singleValueContainer.decode(NpsControllerModel.self)
        case .toggle:
            self.view = try singleValueContainer.decode(ToggleModel.self)
        }
    }
    
}

struct ContainerModel : BaseViewModel {
    let type = ViewType.container
    let border: Border?
    let backgroundColor: HexColor?
    let items: [ContainerItem]
    
    enum CodingKeys : String, CodingKey {
        case border = "border"
        case backgroundColor = "background_color"
        case items = "items"
    }
}

class ContainerItem : Decodable {
    let position: Position
    let margin: Margin?
    let size: Size

    private let _view: BaseViewModelWrapper
    lazy var view: BaseViewModel = {
        return _view.view
    }()
    
    enum CodingKeys: String, CodingKey {
        case position = "position"
        case margin = "margin"
        case size = "size"
        case _view = "view"
    }
}

struct LinearLayoutModel: BaseViewModel {
    let type = ViewType.linearLayout
    let identifier: String?
    let border: Border?
    let backgroundColor: HexColor?
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

class LinearLayoutItem: Decodable {
    let size: Size
    let margin: Margin?
    
    private let _view: BaseViewModelWrapper
    lazy var view: BaseViewModel = {
        return _view.view
    }()

    enum CodingKeys: String, CodingKey {
        case size = "size"
        case margin = "margin"
        case _view = "view"
    }
}

class ScrollLayoutModel: BaseViewModel {
    let type = ViewType.scrollLayout
    let border: Border?
    let backgroundColor: HexColor?
    let direction: Direction
    
    private let _view: BaseViewModelWrapper
    lazy var view: BaseViewModel = {
        return _view.view
    }()
    
    enum CodingKeys: String, CodingKey {
        case border = "border"
        case backgroundColor = "background_color"
        case direction = "direction"
        case _view = "view"
    }
}

struct WebViewModel: BaseViewModel {
    let type = ViewType.webView
    let border: Border?
    let backgroundColor: HexColor?
    let url: String
    
    enum CodingKeys: String, CodingKey {
        case border = "border"
        case backgroundColor = "background_color"
        case url = "url"
    }
}

struct MediaModel: BaseViewModel {
    let type = ViewType.media
    let border: Border?
    let backgroundColor: HexColor?
    let url: String
    let mediaType: MediaType
    
    enum CodingKeys: String, CodingKey {
        case mediaType = "media_type"
        case url = "url"
        case border = "border"
        case backgroundColor = "background_color"
    }
}

struct LabelModel: BaseViewModel {
    let type = ViewType.label
    let border: Border?
    let backgroundColor: HexColor?
    let text: String
    let fontSize: Int
    let foregroundColor: HexColor
    let alignment: TextAlignement?
    let textStyles: [TextStyle]?
    let fontFamilies: [String]?
    
    enum CodingKeys: String, CodingKey {
        case text = "text"
        case fontSize = "font_size"
        case foregroundColor = "foreground_color"
        case alignment = "alignment"
        case textStyles = "text_styles"
        case fontFamilies = "font_families"
        case border = "border"
        case backgroundColor = "background_color"
    }
}

struct LabelButtonModel: ButtonModel {
    let type = ViewType.labelButton
    let identifier: String
    let border: Border?
    let backgroundColor: HexColor?
    let clickBehaviors: [ButtonClickBehavior]?
    let enableBehaviors: [ButtonEnableBehavior]?
    let actions: [String]?
    let label: LabelModel
    let contentDescription: String?
    
    enum CodingKeys: String, CodingKey {
        case identifier = "identifier"
        case border = "border"
        case enableBehaviors = "enable_behaviors"
        case clickBehaviors = "click_behaviors"
        case backgroundColor = "background_color"
        case actions = "actions"
        case label = "label"
        case contentDescription = "content_description"
    }
}

struct ImageButtonModel: ButtonModel {
    let type = ViewType.imageButton
    let identifier: String
    let border: Border?
    let backgroundColor: HexColor?
    let url: String
    let clickBehaviors: [ButtonClickBehavior]?
    let enableBehaviors: [ButtonEnableBehavior]?
    let actions: [String]?
    let contentDescription: String?
    
    enum CodingKeys: String, CodingKey {
        case identifier = "identifier"
        case border = "border"
        case backgroundColor = "background_color"
        case url = "url"
        case enableBehaviors = "enable_behaviors"
        case clickBehaviors = "click_behaviors"
        case actions = "actions"
        case contentDescription = "content_description"

    }
}

struct EmptyViewModel: BaseViewModel {
    let type = ViewType.emptyView
    let border: Border?
    let backgroundColor: HexColor?
    
    enum CodingKeys: String, CodingKey {
        case border = "border"
        case backgroundColor = "background_color"
    }
}

class PagerModel: BaseViewModel {
    let type = ViewType.pager
    let border: Border?
    let backgroundColor: HexColor?
    let disableSwipe: Bool?
    let identifier: String
    
    private let _items: [BaseViewModelWrapper]
    lazy var items: [BaseViewModel] = {
        return _items.map { $0.view }
    }()
    
    
    enum CodingKeys: String, CodingKey {
        case border = "border"
        case backgroundColor = "background_color"
        case _items = "items"
        case disableSwipe = "disable_swipe"
        case identifier = "identifier"
    }
}

class PagerIndicatorModel: BaseViewModel {
    let type = ViewType.pagerIndicator
    let border: Border?
    let backgroundColor: HexColor?
    let bindings: Bindings
    let spacing: Double

    enum CodingKeys: String, CodingKey {
        case border = "border"
        case backgroundColor = "background_color"
        case bindings = "indicator_bindings"
        case spacing = "indicator_spacing"
    }
    
    class Bindings: Decodable {
        private let _selected: BaseShapeModelWrapper
        lazy var selected: BaseShapeModel = {
            return _selected.shape
        }()
        
        private let _deselected: BaseShapeModelWrapper
        lazy var deselected: BaseShapeModel = {
            return _deselected.shape
        }()
        
        enum CodingKeys: String, CodingKey {
            case _selected = "selected"
            case _deselected = "deselected"
        }
    }
}

class PagerControllerModel: BaseViewModel {
    let type = ViewType.pagerController
    let border: Border?
    let backgroundColor: HexColor?
    private let _view: BaseViewModelWrapper
    lazy var view: BaseViewModel = {
        return _view.view
    }()
    
    enum CodingKeys: String, CodingKey {
        case border = "border"
        case backgroundColor = "background_color"
        case _view = "view"
    }
}

class FormControllerModel: BaseViewModel {
    let type = ViewType.formController
    let identifier: String
    let submit: FormSubmitBehavior?
    let border: Border?
    let backgroundColor: HexColor?
    
    private let _view: BaseViewModelWrapper
    lazy var view: BaseViewModel = {
        return _view.view
    }()
    
    enum CodingKeys: String, CodingKey {
        case identifier = "identifier"
        case submit = "submit"
        case border = "border"
        case backgroundColor = "background_color"
        case _view = "view"
    }
}

class NpsControllerModel: BaseViewModel {
    let type = ViewType.formController
    let identifier: String
    let submit: FormSubmitBehavior?
    let border: Border?
    let backgroundColor: HexColor?
    let npsIdentifier: String

    
    private let _view: BaseViewModelWrapper
    lazy var view: BaseViewModel = {
        return _view.view
    }()
    
    enum CodingKeys: String, CodingKey {
        case identifier = "identifier"
        case submit = "submit"
        case border = "border"
        case backgroundColor = "background_color"
        case _view = "view"
        case npsIdentifier = "nps_identifier"
    }
}


class CheckboxControllerModel: BaseViewModel {
    let type = ViewType.checkboxController
    let identifier: String
    let border: Border?
    let backgroundColor: HexColor?
    let isRequired: Bool?
    let minSelection: Int?
    let maxSelection: Int?
    
    private let _view: BaseViewModelWrapper
    lazy var view: BaseViewModel = {
        return _view.view
    }()
    
    enum CodingKeys: String, CodingKey {
        case identifier = "identifier"
        case border = "border"
        case backgroundColor = "background_color"
        case _view = "view"
        case isRequired = "required"
        case minSelection = "min_selection"
        case maxSelection = "max_selection"
    }
}

class RadioInputControllerModel: BaseViewModel {
    let type = ViewType.radioInputController
    let identifier: String
    let submit: FormSubmitBehavior?
    let border: Border?
    let backgroundColor: HexColor?
    let isRequired: Bool?

    private let _view: BaseViewModelWrapper
    lazy var view: BaseViewModel = {
        return _view.view
    }()
    
    enum CodingKeys: String, CodingKey {
        case identifier = "identifier"
        case submit = "submit"
        case border = "border"
        case backgroundColor = "background_color"
        case _view = "view"
        case isRequired = "required"
    }
}

struct TextInputModel: BaseViewModel {
    let type = ViewType.textInput
    let border: Border?
    let backgroundColor: HexColor?
    let fontSize: Int
    let foregroundColor: HexColor
    let textStyles: [TextStyle]?
    let fontFamilies: [String]?
    let identifier: String
    let contentDescription: String?
    let isRequired: Bool?
    let placeHolder: String?

    enum CodingKeys: String, CodingKey {
        case fontSize = "font_size"
        case foregroundColor = "foreground_color"
        case textStyles = "text_styles"
        case fontFamilies = "font_families"
        case border = "border"
        case backgroundColor = "background_color"
        case identifier = "identifier"
        case contentDescription = "content_description"
        case isRequired = "required"
        case placeHolder = "place_holder"
    }
}

class ToggleModel: BaseViewModel {
    let type = ViewType.toggle
    let border: Border?
    let backgroundColor: HexColor?
    let identifier: String
    let contentDescription: String?
    let isRequired: Bool?
    
    private let _style: BaseToggleStyleModelWrapper
    lazy var style: BaseToggleStyleModel = {
        return _style.style
    }()

    enum CodingKeys: String, CodingKey {
        case border = "border"
        case backgroundColor = "background_color"
        case identifier = "identifier"
        case contentDescription = "content_description"
        case isRequired = "required"
        case _style = "style"
    }
}

class CheckboxModel: BaseViewModel {
    let type = ViewType.checkbox
    let border: Border?
    let backgroundColor: HexColor?
    let contentDescription: String?
    let value: String
    
    private let _style: BaseToggleStyleModelWrapper
    lazy var style: BaseToggleStyleModel = {
        return _style.style
    }()
    
    enum CodingKeys: String, CodingKey {
        case border = "border"
        case backgroundColor = "background_color"
        case contentDescription = "content_description"
        case value = "value"
        case _style = "style"
    }
}

struct RadioInputModel: BaseViewModel {
    let type = ViewType.radioInput
    let border: Border?
    let backgroundColor: HexColor?
    let foregroundColor: HexColor
    let contentDescription: String?
    let value: String
    
    enum CodingKeys: String, CodingKey {
        case foregroundColor = "foreground_color"
        case border = "border"
        case backgroundColor = "background_color"
        case contentDescription = "content_description"
        case value = "value"
    }
}

struct ScoreModel: BaseViewModel {
    let type = ViewType.score
    let border: Border?
    let backgroundColor: HexColor?
    let foregroundColor: HexColor
    let identifier: String
    let contentDescription: String?
    let isRequired: Bool
    
    enum CodingKeys: String, CodingKey {
        case foregroundColor = "foreground_color"
        case border = "border"
        case backgroundColor = "background_color"
        case identifier = "identifier"
        case contentDescription = "content_description"
        case isRequired = "required"
    }
}

protocol BaseToggleStyleModel: Decodable {
    var type: ToggleStyleType { get }
}

private struct BaseToggleStyleModelWrapper : Decodable {
    let style: BaseToggleStyleModel

    private enum CodingKeys: String, CodingKey {
        case type
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(ToggleStyleType.self, forKey: .type)
        let singleValueContainer = try decoder.singleValueContainer()

        switch type {
        case .switchStyle:
            self.style = try singleValueContainer.decode(SwitchToggleStyleModel.self)
        case .checkboxStyle:
            self.style = try singleValueContainer.decode(CheckboxToggleStyleModel.self)
        }
    }
}

struct SwitchToggleStyleModel: BaseToggleStyleModel {
    let type = ToggleStyleType.switchStyle
    let colors: ToggleColors
    
    enum CodingKeys: String, CodingKey {
        case colors = "toggle_colors"
    }
    
    struct ToggleColors: Decodable {
        var on: HexColor
        var off: HexColor

        enum CodingKeys: String, CodingKey {
            case on = "on"
            case off = "off"
        }
    }
}

struct CheckboxToggleStyleModel: BaseToggleStyleModel {
    let type = ToggleStyleType.checkboxStyle
    let checkedColors: CheckedColors
    
    enum CodingKeys: String, CodingKey {
        case checkedColors = "checked_colors"
    }
    
    struct CheckedColors: Decodable {
        var checkMark: HexColor
        var border: HexColor?
        var background: HexColor?

        enum CodingKeys: String, CodingKey {
            case checkMark = "check_mark"
            case border = "border"
            case background = "background"
        }
    }
}

protocol BaseShapeModel: Decodable {
    var type: ShapeType { get }
    var border: Border? { get }
    var color: HexColor? { get }
}

private struct BaseShapeModelWrapper : Decodable {
    let shape: BaseShapeModel

    private enum CodingKeys: String, CodingKey {
        case type
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(ShapeType.self, forKey: .type)
        let singleValueContainer = try decoder.singleValueContainer()

        switch type {
        case .rectangle:
            self.shape = try singleValueContainer.decode(RectangleShapeModel.self)
        case .circle:
            self.shape = try singleValueContainer.decode(CircleShapeModel.self)
        }
    }
}


struct CircleShapeModel: BaseShapeModel {
    let type = ShapeType.circle
    let border: Border?
    let radius: Double
    let color: HexColor?
    
    enum CodingKeys: String, CodingKey {
        case border = "border"
        case color = "color"
        case radius = "radius"
    }
}

struct RectangleShapeModel: BaseShapeModel {
    let type = ShapeType.rectangle
    let border: Border?
    let width: Double
    let height: Double
    let color: HexColor?
    
    enum CodingKeys: String, CodingKey {
        case border = "border"
        case color = "color"
        case width = "width"
        case height = "height"
    }
}

struct Size: Decodable {
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

struct Border: Decodable {
    var radius: Double?
    var strokeWidth: Double?
    var strokeColor: HexColor?
    
    enum CodingKeys: String, CodingKey {
        case radius = "radius"
        case strokeWidth = "stroke_width"
        case strokeColor = "stroke_color"
    }
}

struct Margin: Decodable {
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

struct Position: Decodable {
    let horizontal: HorizontalPosition
    let vertical: VerticalPosition
    
    enum CodingKeys: String, CodingKey {
        case horizontal = "horizontal"
        case vertical = "vertical"
    }
}

enum Direction: String, Decodable {
    case vertical = "vertical"
    case horizontal = "horizontal"
}

enum HorizontalPosition: String, Decodable {
    case center = "center"
    case start = "start"
    case end = "end"
}

enum VerticalPosition: String, Decodable {
    case center = "center"
    case top = "top"
    case bottom = "bottom"
}

enum MediaType: String, Decodable {
    case image = "image"
    case video = "video"
    case youtube = "youtube"
}

enum TextAlignement: String, Decodable {
    case start = "start"
    case end = "end"
    case center = "center"
}

enum TextInputType: String, Decodable {
    case email = "email"
    case number = "number"
    case text = "text"
    case textMultiline = "text_multiline"
}

enum TextStyle: String, Decodable {
    case bold = "bold"
    case italic = "italic"
    case underlined = "underlined"
}

enum ButtonEnableBehavior: String, Decodable {
    case formValidation = "form_validation"
    case pagerNext = "pager_next"
    case pagerPrevious = "pager_previous"
}

enum ButtonClickBehavior: String, Decodable {
    case dismiss = "dismiss"
    case cancel = "cancel"
    case pagerNext = "pager_next"
    case pagerPrevious = "pager_previous"
    case formSubmit = "form_submit"
}

enum FormSubmitBehavior: String, Decodable {
    case submitEvent = "submit_event"
}

struct HexColor : Decodable {
    let hexColor: String
    let alpha: Double?
    
    enum CodingKeys: String, CodingKey {
        case hexColor = "hex"
        case alpha = "alpha"
    }
}
