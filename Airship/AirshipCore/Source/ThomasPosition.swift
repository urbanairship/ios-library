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
