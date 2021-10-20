import Foundation

struct ModalModal: Decodable {
    let placementSelectors: [ModalPlacementSelector]?
    let defaultPlacement: ModalPlacement

    enum CodingKeys: String, CodingKey {
        case placementSelectors = "placement_selectors"
        case defaultPlacement = "default_placement"
    }
}

struct ModalPlacement : Decodable {
    let margin: Margin?
    let size: Size?
    let position: Position?
    let shade: HexColor?
    
    enum CodingKeys: String, CodingKey {
        case margin = "margin"
        case size = "size"
        case position = "position"
        case shade = "shade"
    }
}

struct ModalPlacementSelector : Decodable {
    let placement: ModalPlacement
    let windowSize: WindowSize
    let orientation: Orientation
    
    enum CodingKeys : String, CodingKey {
        case placement = "placement"
        case windowSize = "windowSize"
        case orientation = "orientation"
    }
}

enum WindowSize : String, Decodable {
    case small = "small"
    case medium = "medium"
    case large = "large"
}

enum Orientation : String, Decodable {
    case portrait = "portrait"
    case landscape = "landscape"
}
