/* Copyright Airship and Contributors */

import Foundation

/// NOTE: For internal use only. :nodoc:

enum AttributeUpdateType: Int, Codable, Sendable, Equatable {
    case remove
    case set
}

/// NOTE: For internal use only. :nodoc:
struct AttributeUpdate: Codable, Sendable, Equatable {
    let attribute: String
    let type: AttributeUpdateType
    let jsonValue: AirshipJSON?
    let date: Date

    static func remove(
        attribute: String,
        date: Date = Date()
    ) -> AttributeUpdate {
        return AttributeUpdate(
            attribute: attribute,
            type: .remove,
            jsonValue: nil,
            date: date
        )
    }

    static func set(
        attribute: String,
        value: AirshipJSON,
        date: Date = Date()
    ) -> AttributeUpdate {
        return AttributeUpdate(
            attribute: attribute,
            type: .set,
            jsonValue: value,
            date: date
        )
    }

    init(attribute: String, type: AttributeUpdateType, jsonValue: AirshipJSON?, date: Date) {
        self.attribute = attribute
        self.type = type
        self.jsonValue = jsonValue
        self.date = date
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.attribute = try container.decode(String.self, forKey: .attribute)
        self.type = try container.decode(AttributeUpdateType.self, forKey: .type)
        self.date = try container.decode(Date.self, forKey: .date)


        do {
            self.jsonValue = try container.decodeIfPresent(AirshipJSON.self, forKey: .jsonValue)
        } catch {
            let legacy = try? container.decodeIfPresent(JsonValue.self, forKey: .jsonValue)
            guard let legacy = legacy else {
                throw error
            }

            if let decoder = decoder as? JSONDecoder {
                self.jsonValue = try AirshipJSON.from(
                    json: legacy.jsonEncodedValue,
                    decoder: decoder
                )
            } else {
                self.jsonValue = try AirshipJSON.from(
                    json: legacy.jsonEncodedValue
                )
            }
        }
    }

    // Migration purposes
    fileprivate struct JsonValue : Decodable {
        let jsonEncodedValue: String?
    }
}


extension AttributeUpdate {
    var operation: AttributeOperation {
        let timestamp = AirshipDateFormatter.string(fromDate: date, format: .isoDelimitter)
        switch self.type {
        case .set:
            return AttributeOperation(
                action: .set,
                key: self.attribute,
                timestamp: timestamp,
                value: self.jsonValue
            )
        case .remove:
            return AttributeOperation(
                action: .remove,
                key: self.attribute,
                timestamp: timestamp,
                value: nil
            )
        }
    }
}

/// NOTE: For internal use only. :nodoc:
// Used by ChannelBulkAPIClient and DeferredAPIClient

struct AttributeOperation: Encodable {
    enum AttributeAction: String, Encodable {
        case set
        case remove
    }

    var action: AttributeAction
    var key: String
    var timestamp: String
    var value: AirshipJSON?
}

