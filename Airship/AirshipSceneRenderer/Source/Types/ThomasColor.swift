/* Copyright Airship and Contributors */

import Foundation
import SwiftUI
@_spi(AirshipInternal) import AirshipBasement

/// What a scene gives anywhere it takes a color: the color, or the name of one in the scene's `references`.
enum ThomasColor: ThomasSerializable {
    case color(Definition)
    case reference(name: String)

    struct Definition: ThomasSerializable {
        let defaultColor: HexColor
        let selectors: [Selector]?

        enum CodingKeys: String, CodingKey {
            case defaultColor = "default"
            case selectors
        }
    }

    struct HexColor: ThomasSerializable {
        let type: String = "hex"
        var hex: String
        var alpha: Double?

        enum CodingKeys: String, CodingKey {
            case type
            case hex
            case alpha
        }
    }

    struct Selector: ThomasSerializable, ThomasSelectorConditions {
        let darkMode: Bool?
        let platform: ThomasPlatform?
        let windowSize: ThomasWindowSize?
        let orientation: ThomasOrientation?
        let environmentConditions: [String: AirshipJSON]?
        let color: HexColor

        enum CodingKeys: String, CodingKey {
            case platform
            case darkMode = "dark_mode"
            case windowSize = "window_size"
            case orientation
            case environmentConditions = "environment_conditions"
            case color
        }
    }

    private enum ReferenceType: String, Codable {
        case colorReference = "color_reference"
    }

    private enum ReferenceCodingKeys: String, CodingKey {
        case type
        case name
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: ReferenceCodingKeys.self)
        if container.contains(.type) {
            _ = try container.decode(ReferenceType.self, forKey: .type)
            self = .reference(name: try container.decode(String.self, forKey: .name))
        } else {
            self = .color(try Definition(from: decoder))
        }
    }

    func encode(to encoder: any Encoder) throws {
        switch self {
        case .color(let definition):
            try definition.encode(to: encoder)
        case .reference(let name):
            var container = encoder.container(keyedBy: ReferenceCodingKeys.self)
            try container.encode(ReferenceType.colorReference, forKey: .type)
            try container.encode(name, forKey: .name)
        }
    }
}

/// A scene's named values, which references elsewhere in the scene look up by name.
struct ThomasSceneReferences: ThomasSerializable {
    /// Colors a `ThomasColor.reference` can name.
    var colors: [String: ThomasColor.Definition]?
}

extension ThomasColor.HexColor {
    func toColor() -> Color {
        // Use the new AirshipColor resolver instead of AirshipColorUtils
        let color = AirshipColor.resolveColor(self.hex)
        let alpha = self.alpha ?? 1.0

        // Combine the hex color with the explicit alpha multiplier
        let finalColor = color.opacity(alpha)

        /// Clear needs to be replaced by tappable clear to prevent SwiftUI from passing through tap events
        /// Note: We check if the resulting alpha is 0 (either from hex or explicit alpha)
        if alpha == 0 || color == .clear {
            return ThomasConstants.tappableClearColor
        }

        return finalColor
    }
}

extension ThomasColor.Definition {
    /// Opaque black, which a reference the scene doesn't define draws as.
    static let missing = ThomasColor.Definition(
        defaultColor: ThomasColor.HexColor(hex: "#000000", alpha: 1),
        selectors: nil
    )

    func toColor(_ environment: ThomasSelectorEnvironment) -> Color {
        (selectors?.firstMatch(environment)?.color ?? defaultColor).toColor()
    }
}

extension ThomasColor {
    /// Names already logged as unknown, since a color resolves on every render.
    private static let loggedUnknownNames: AirshipAtomicValue<Set<String>> = AirshipAtomicValue([])

    /// Returns the color itself, or the named color a reference looks up in `environment`.
    ///
    /// - Parameter environment: what the scene is shown in, which carries its named colors
    /// - Returns: the definition; opaque black for a name `environment` doesn't define
    func definition(_ environment: ThomasSelectorEnvironment) -> Definition {
        switch self {
        case .color(let definition):
            return definition
        case .reference(let name):
            guard let definition = environment.colors[name] else {
                var isFirst = false
                Self.loggedUnknownNames.update { isFirst = $0.insert(name).inserted }
                if isFirst {
                    AirshipLogger.error("Unknown color reference \(name)")
                }
                return .missing
            }
            return definition
        }
    }

    func toColor(_ environment: ThomasSelectorEnvironment) -> Color {
        definition(environment).toColor(environment)
    }
}
