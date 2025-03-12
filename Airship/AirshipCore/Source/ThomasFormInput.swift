/* Copyright Airship and Contributors */

import Foundation

struct ThomasFormInput: Sendable, Equatable {

    enum ChannelRegistration: Sendable, Equatable {
        case email(String, ThomasEmailRegistrationOptions)
    }

    struct Attribute: Sendable, Equatable {
        let attributeName: ThomasAttributeName
        let attributeValue: ThomasAttributeValue
    }

    enum Value: Sendable, Equatable {
        case toggle(Bool)
        case radio(String?)
        case multipleCheckbox([String]?)
        case form(responseType: String?, children: [ThomasFormInput])
        case npsForm(responseType: String?, scoreID: String, children: [ThomasFormInput])
        case text(String?)
        case emailText(String?)
        case score(Int?)

        var unwrappedValue: (any Encodable)? {
            switch self {
            case .toggle(let value): return value
            case .radio(let value): return value
            case .multipleCheckbox(let value): return value
            case .form(_, let value): return value.map { $0.toPayload() }
            case .npsForm(_, _, let value): return value.map { $0.toPayload() }
            case .text(let value): return value
            case .emailText(let value): return value
            case .score(let value): return value
            }
        }
    }

    private static let typeKey = "type"
    private static let valueKey = "value"
    private static let childrenKey = "children"
    private static let scoreIDKey = "score_id"
    private static let responseTypeKey = "response_type"

    let identifier: String
    let value: Value

    private let channelRegistration: ChannelRegistration?
    private let attribute: Attribute?

    init(
        _ identifier: String,
        value: Value,
        attribute: Attribute? = nil,
        channelRegistration: ChannelRegistration? = nil
    ) {
        self.identifier = identifier
        self.value = value
        self.attribute = attribute
        self.channelRegistration = channelRegistration
    }

    fileprivate var allInputs: [ThomasFormInput] {
        var result: [ThomasFormInput] = []
        result.append(self)

        if case let .form(_, children) = self.value {
            children.forEach { child in
                result.append(contentsOf: child.allInputs)
            }
        }

        if case let .npsForm(_, _, children) = self.value {
            children.forEach { child in
                result.append(contentsOf: child.allInputs)
            }
        }
        return result
    }

    var attributes: [Attribute] {
        self.allInputs.compactMap { $0.attribute }
    }

    var channels: [ChannelRegistration] {
        self.allInputs.compactMap { $0.channelRegistration }
    }

    func toPayload() -> AirshipJSON {
        guard let data = self.getData() else { return AirshipJSON.object([:]) }
        do {
            return try AirshipJSON.wrap([self.identifier: data])
        } catch {
            AirshipLogger.error("Failed to wrap form data \(error)")
        }
        return AirshipJSON.object([:])
    }

    func getData() -> [String: Any]? {
        switch self.value {
        case .toggle(let value):
            return [
                ThomasFormInput.typeKey: "toggle",
                ThomasFormInput.valueKey: value,
            ]
        case .radio(let value):
            guard let value else { return nil }

            return [
                ThomasFormInput.typeKey: "single_choice",
                ThomasFormInput.valueKey: value,
            ]
        case .multipleCheckbox(let value):
            guard let value else { return nil }
            return [
                ThomasFormInput.typeKey: "multiple_choice",
                ThomasFormInput.valueKey: value,
            ]
        case .text(let value):
            guard let value else { return nil }

            return [
                ThomasFormInput.typeKey: "text_input",
                ThomasFormInput.valueKey: value,
            ]
        case .emailText(let value):
            guard let value else { return nil }

            return [
                ThomasFormInput.typeKey: "email_input",
                ThomasFormInput.valueKey: value,
            ]
        case .score(let value):
            guard let value else { return nil }

            return [
                ThomasFormInput.typeKey: "score",
                ThomasFormInput.valueKey: value,
            ]
        case .form(let responseType, let children):
            return [
                ThomasFormInput.typeKey: "form",
                ThomasFormInput.responseTypeKey: responseType as Any,
                ThomasFormInput.childrenKey: children.reduce(into: [String: Any]()) {
                    $0[$1.identifier] = $1.getData()
                }
            ]
        case .npsForm(let responseType, let scoreID, let children):
            return [
                ThomasFormInput.typeKey: "nps",
                ThomasFormInput.responseTypeKey: responseType as Any,
                ThomasFormInput.scoreIDKey: scoreID,
                ThomasFormInput.childrenKey: children.reduce(into: [String: Any]()) {
                    $0[$1.identifier] = $1.getData()
                }
            ]
        }
    }
}
