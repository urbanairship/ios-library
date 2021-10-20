import Foundation

struct BannerModal : Decodable {
    let duration: Int
    let position: String
    let margin: Margin?
    let size: Size?
    
    enum CodingKeys : String, CodingKey {
        case duration = "duration"
        case position = "position"
        case margin = "margin"
        case size = "size"
    }
}
