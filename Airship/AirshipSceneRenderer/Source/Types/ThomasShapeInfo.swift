/* Copyright Airship and Contributors */

import Foundation

enum ThomasShapeInfo: ThomasSerializable {
    case rectangle(Rectangle)
    case ellipse(Ellipse)

    enum CodingKeys: String, CodingKey {
        case type = "type"
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(ShapeType.self, forKey: .type)

        self = switch type {
        case .ellipse: .ellipse(try Ellipse(from: decoder))
        case .rectangle: .rectangle(try Rectangle(from: decoder))
        }
    }

    func encode(to encoder: any Encoder) throws {
        switch self {
        case .ellipse(let shape): try shape.encode(to: encoder)
        case .rectangle(let shape): try shape.encode(to: encoder)
        }
    }

    enum ShapeType: String, ThomasSerializable {
        case rectangle
        case ellipse
    }

    struct Ellipse: Codable, Equatable, Sendable {
        let type: ShapeType = .ellipse
        var border: ThomasBorder?
        var scale: Double?
        var color: ThomasColor?
        var aspectRatio: Double?

        enum CodingKeys: String, CodingKey {
            case border
            case color
            case scale
            case aspectRatio = "aspect_ratio"
            case type
        }
    }

    struct Rectangle: Codable, Equatable, Sendable {
        let type: ShapeType = .rectangle
        var border: ThomasBorder?
        var scale: Double?
        var color: ThomasColor?
        var aspectRatio: Double?

        enum CodingKeys: String, CodingKey {
            case border
            case color
            case scale
            case aspectRatio = "aspect_ratio"
            case type
        }
    }
}
