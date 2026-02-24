/* Copyright Airship and Contributors */

import SwiftUI
import Foundation
import AirshipCore

struct AirshipJSONView: View {
    let json: AirshipJSON

    init(json: AirshipJSON) {
        self.json = json
    }

    @ViewBuilder
    public var body: some View {
        switch (json) {
        case .object(let object):
            List(Array(object.keys), id: \.self) { key in
                if let value = object[key] {
                    ObjectEntry(key: key, value: value)
                }
            }
        default:
            Text(json.prettyString)
        }

    }
}

extension String {
    var quoted: String {
        return "\"\(self)\""
    }
}

extension AirshipJSON {
    static let prettyEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        return encoder
    }()

    static func wrapSafe(_ any: Any?) -> AirshipJSON {
        do {
            return try AirshipJSON.wrap(any)
        } catch {
            return AirshipJSON.string("Error \(error)")
        }
    }

    var prettyString: String {
        do {
            return try self.toString(encoder: AirshipJSON.prettyEncoder)
        } catch {
            return "Error: \(error)"
        }
    }

    var typeString: String {
        switch(self) {
        case .object: return "object"
        case .string: return "string"
        case .number: return "number"
        case .array: return "array"
        case .bool: return "boolean"
        case .null: return "null"
        @unknown default: return "unknown"
        }
    }
}

fileprivate struct ObjectEntry: View {
    let key: String
    let value: AirshipJSON

    @State private var collapsed: Bool = false

    var body: some View {
        VStack(alignment: .leading) {
            Button(
                action: { self.collapsed.toggle() },
                label: {
                    HStack {
                        Text(key.quoted) + Text(": ") + Text(value.typeString).italic().font(.system(size: 12))
                        Spacer()
                        Image(systemName: self.collapsed ? "chevron.down" : "chevron.up")
                    }
                    .contentShape(Rectangle())
                }
            )
            .buttonStyle(PlainButtonStyle())
            .frame(minHeight: 36)

            VStack(alignment: .leading) {
                Text(value.prettyString)
                    .font(.subheadline)
                    .frame(maxWidth: .infinity, alignment: .leading)

            }
            .padding(8)
            .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: collapsed ? 0 : .none)
            .clipped()
            .animation(.easeOut, value: self.collapsed)
            .transition(.slide)
        }
    }
}

#Preview {
    AirshipJSONView(json: ["preview": true])
}
