/* Copyright Airship and Contributors */

import Foundation
import SwiftUI

struct ThomasPosition: ThomasSerializable {
    var horizontal: Horizontal
    var vertical: Vertical

    enum Horizontal: String, ThomasSerializable {
        case center
        case start
        case end
    }

    enum Vertical: String, ThomasSerializable {
        case center
        case top
        case bottom
    }
}

enum ThomasHorizontalEdge: String, ThomasSerializable {
    case start
    case end
    
    var baseType: ThomasPosition.Horizontal {
        switch self {
        case .start: return .start
        case .end: return .end
        }
    }
}

enum ThomasVerticalEdge: String, ThomasSerializable {
    case top
    case bottom
    
    var baseType: ThomasPosition.Vertical {
        switch self {
        case .top: return .top
        case .bottom: return .bottom
        }
    }
}

struct ThomasCornerPosition: ThomasSerializable {
    var horizontal: ThomasHorizontalEdge
    var vertical: ThomasVerticalEdge
    
    var asPosition: ThomasPosition {
        ThomasPosition(horizontal: horizontal.baseType, vertical: vertical.baseType)
    }
}

struct ThomasEdgePosition: ThomasSerializable {
    var horizontal: ThomasPosition.Horizontal
    var vertical: ThomasPosition.Vertical
    
    enum PositionError: Error {
        case invalidEdgePosition
    }
    
    init(horizontal: ThomasPosition.Horizontal, vertical: ThomasPosition.Vertical) throws {
        guard horizontal != .center || vertical != .center else {
            throw PositionError.invalidEdgePosition
        }
        
        self.horizontal = horizontal
        self.vertical = vertical
    }
    
    var asPosition: ThomasPosition {
        ThomasPosition(horizontal: horizontal, vertical: vertical)
    }
}

extension ThomasEdgePosition {
    private enum CodingKeys: String, CodingKey {
        case horizontal
        case vertical
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let decodedHorizontal = try container.decode(ThomasPosition.Horizontal.self, forKey: .horizontal)
        let decodedVertical = try container.decode(ThomasPosition.Vertical.self, forKey: .vertical)
        
        guard decodedHorizontal != .center || decodedVertical != .center else {
            throw DecodingError.dataCorruptedError(
                forKey: .horizontal,
                in: container,
                debugDescription: "EdgePosition cannot have both horizontal and vertical set to center."
            )
        }
        
        self.horizontal = decodedHorizontal
        self.vertical = decodedVertical
    }
}

extension ThomasPosition {
    var alignment: Alignment {
        Alignment(horizontal: horizontal.alignment, vertical: vertical.alignment)
    }
}

extension ThomasPosition.Vertical {
    var alignment: VerticalAlignment {
        switch self {
        case .top: return VerticalAlignment.top
        case .center: return VerticalAlignment.center
        case .bottom: return VerticalAlignment.bottom
        }
    }
}

extension ThomasPosition.Horizontal {
    var alignment: HorizontalAlignment {
        switch self {
        case .start: return HorizontalAlignment.leading
        case .center: return HorizontalAlignment.center
        case .end: return HorizontalAlignment.trailing
        }
    }
}
