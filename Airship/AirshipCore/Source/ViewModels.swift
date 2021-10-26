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
enum ViewType: String, Decodable {
    case container = "container"
    case linearLayout = "linear_layout"
    case webView = "web_view"
    case scrollLayout = "scroll_layout"
    case media = "media"
    case label = "label"
    case button = "button"
    case imageButton = "image_button"
    case emptyView = "empty_view"
    case carousel = "carousel"
    case carouselIndicator = "carousel_indicator"
    case carouselController = "carousel_controller"
}

protocol BaseViewModel : Decodable {
    var type: ViewType { get }
    var identifier: String? { get }
    var border: Border? { get }
    var background: HexColor? { get }
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
        case .button:
            self.view = try singleValueContainer.decode(ButtonModel.self)
        case .imageButton:
            self.view = try singleValueContainer.decode(ImageButtonModel.self)
        case .emptyView:
            self.view = try singleValueContainer.decode(EmptyViewModel.self)
        case .carousel:
            self.view = try singleValueContainer.decode(CarouselModel.self)
        case .carouselIndicator:
            self.view = try singleValueContainer.decode(CarouselIndicatorModel.self)
        case .carouselController:
            self.view = try singleValueContainer.decode(CarouselControllerModel.self)
        }
    }
}

struct ContainerModel : BaseViewModel {
    let type = ViewType.container
    let identifier: String?
    let border: Border?
    let background: HexColor?
    let items: [ContainerItem]
    
    enum CodingKeys : String, CodingKey {
        case identifier = "identifier"
        case border = "border"
        case background = "background"
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
    let background: HexColor?
    let direction: Direction
    let items: [LinearLayoutItem]
    
    enum CodingKeys: String, CodingKey {
        case items = "items"
        case identifier = "identifier"
        case border = "border"
        case background = "background"
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
    let identifier: String?
    let border: Border?
    let background: HexColor?
    let direction: Direction
    
    private let _view: BaseViewModelWrapper
    lazy var view: BaseViewModel = {
        return _view.view
    }()
    
    enum CodingKeys: String, CodingKey {
        case identifier = "identifier"
        case border = "border"
        case background = "background"
        case direction = "direction"
        case _view = "view"
    }
}

struct WebViewModel: BaseViewModel {
    let type = ViewType.webView
    let identifier: String?
    let border: Border?
    let background: HexColor?
    let url: String
    
    enum CodingKeys: String, CodingKey {
        case identifier = "identifier"
        case border = "border"
        case background = "background"
        case url = "url"
    }
}

struct MediaModel: BaseViewModel {
    let type = ViewType.media
    let identifier: String?
    let border: Border?
    let background: HexColor?
    let url: String
    let mediaType: MediaType
    
    enum CodingKeys: String, CodingKey {
        case mediaType = "media_type"
        case url = "url"
        case identifier = "identifier"
        case border = "border"
        case background = "background"
    }
}

struct LabelModel: BaseViewModel {
    let type = ViewType.label
    let identifier: String?
    let border: Border?
    let background: HexColor?
    let text: String
    let fontSize: Int
    let color: HexColor
    let alignment: TextAlignement?
    let textStyles: [TextStyles]?
    let fontFamilies: [String]?
    
    enum CodingKeys: String, CodingKey {
        case text = "text"
        case fontSize = "font_size"
        case color = "color"
        case alignment = "alignment"
        case textStyles = "text_styles"
        case fontFamilies = "font_families"
        case identifier = "identifier"
        case border = "border"
        case background = "background"
    }
}

struct ButtonModel: BaseViewModel {
    let type = ViewType.button
    let identifier: String?
    let border: Border?
    let background: HexColor?
    let behavior: Behavior?
    let actions: Array<String>?
    let label: LabelModel
    
    enum CodingKeys: String, CodingKey {
        case identifier = "identifier"
        case border = "border"
        case behavior = "behavior"
        case background = "background"
        case actions = "actions"
        case label = "label"
    }
}

struct ImageButtonModel: BaseViewModel {
    let type = ViewType.imageButton
    let identifier: String?
    let border: Border?
    let background: HexColor?
    let url: String
    let behavior: Behavior?
    let actions: Array<String>?
    
    enum CodingKeys: String, CodingKey {
        case identifier = "identifier"
        case border = "border"
        case background = "background"
        case url = "url"
        case behavior = "behavior"
        case actions = "actions"
    }
}

struct EmptyViewModel: BaseViewModel {
    let type = ViewType.emptyView
    let identifier: String?
    let border: Border?
    let background: HexColor?
    
    enum CodingKeys: String, CodingKey {
        case identifier = "identifier"
        case border = "border"
        case background = "background"
    }
}

struct CarouselModel: BaseViewModel {
    let type = ViewType.carousel
    let identifier: String?
    let border: Border?
    let background: HexColor?
    
    private let _items: [BaseViewModelWrapper]
    lazy var items: [BaseViewModel] = {
        return _items.map { $0.view }
    }()
    
    enum CodingKeys: String, CodingKey {
        case identifier = "identifier"
        case border = "border"
        case background = "background"
        case _items = "items"
    }
}

struct CarouselIndicatorModel: BaseViewModel {
    let type = ViewType.carouselIndicator
    let identifier: String?
    let border: Border?
    let background: HexColor?
    let carouselIdentifier: String
    
    enum CodingKeys: String, CodingKey {
        case identifier = "identifier"
        case border = "border"
        case background = "background"
        case carouselIdentifier = "carousel_identifier"
    }
}


struct CarouselControllerModel: BaseViewModel {
    let type = ViewType.carouselController
    let identifier: String?
    let border: Border?
    let background: HexColor?
    let items: [ContainerItem]
    
    enum CodingKeys: String, CodingKey {
        case identifier = "identifier"
        case border = "border"
        case background = "background"
        case items = "items"
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
    let radius: Double?
    let strokeWidth: Double?
    let strokeColor: HexColor?
    
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

enum TextStyles: String, Decodable {
    case bold = "bold"
    case italic = "italic"
    case underline = "underline"
}

enum Behavior: String, Decodable {
    case dismiss = "dismiss"
    case cancel = "cancel"
}

struct HexColor : Decodable {
    let hexColor: String
    let alpha: Double?
    
    enum CodingKeys: String, CodingKey {
        case hexColor = "hex"
        case alpha = "alpha"
    }
}
