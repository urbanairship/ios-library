/* Copyright Airship and Contributors */

import Foundation
@_spi(AirshipInternal) import AirshipBasement

/// Registration overrides for the inputs of one form, applied on form submission.
///
/// Predicates and state values are read from the form's state at submit, never while the user is
/// filling the form in. Every matching override applies, in list order, on top of the input's own
/// `email_registration`, and an input with none registers once a patch supplies a `type`.
struct ThomasFormRegistrationOverrides: ThomasSerializable {
    var email: [ThomasEmailRegistrationOverride]?

    /// Returns the email registration for an input after applying every matching override.
    ///
    /// For example, an input with `transactional` options and a matching override of
    /// `{type: commercial, commercial_opted_in: {type: value, value: true}}` resolves to
    /// `.commercial(optedIn: true)`, keeping the input's properties.
    ///
    /// - Parameters:
    ///   - inputID: The email input's identifier.
    ///   - options: The input's own `email_registration`.
    ///   - state: The form's state, the root both predicates and `state` patch values read from.
    /// - Returns: The resolved options, or nil when neither the input nor a patch supplies a type.
    func resolveEmail(
        inputID: String,
        options: ThomasEmailRegistrationOption?,
        state: AirshipJSON
    ) -> ThomasEmailRegistrationOption? {
        var draft = EmailRegistrationDraft(options: options)
        email?.forEach { override in
            guard
                override.inputID == nil || override.inputID == inputID,
                override.whenStateMatches.evaluate(json: state)
            else {
                return
            }
            draft.apply(override.registration, state: state)
        }
        return draft.options
    }
}

struct ThomasEmailRegistrationOverride: ThomasSerializable {
    /// The email input to patch; nil patches every email input in the form.
    var inputID: String?
    var whenStateMatches: JSONPredicate
    var registration: ThomasEmailRegistrationPatch

    enum CodingKeys: String, CodingKey {
        case inputID = "input_id"
        case whenStateMatches = "when_state_matches"
        case registration
    }
}

/// The fields of an email registration an override changes; nil fields keep the input's value.
struct ThomasEmailRegistrationPatch: ThomasSerializable {
    var type: ThomasEmailRegistrationOption.EmailRegistrationType?
    var commercialOptedIn: ThomasPatchValue?
    var openTrackingOptedIn: ThomasPatchValue?
    var clickTrackingOptedIn: ThomasPatchValue?
    var properties: PropertiesPatch?

    enum CodingKeys: String, CodingKey {
        case type
        case commercialOptedIn = "commercial_opted_in"
        case openTrackingOptedIn = "open_tracking_opted_in"
        case clickTrackingOptedIn = "click_tracking_opted_in"
        case properties
    }

    /// Changes to `properties`, one top-level key at a time. `remove` runs before `set`.
    struct PropertiesPatch: ThomasSerializable {
        var set: [String: ThomasPatchValue]?
        var remove: [String]?
    }
}

/// A patch value, either written into the layout or read from the form's state at submit.
enum ThomasPatchValue: ThomasSerializable {
    case value(AirshipJSON)
    case state(scope: [String])

    private enum CodingKeys: String, CodingKey {
        case type
        case value
        case scope
    }

    private enum PatchValueType: String, Codable {
        case value
        case state
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        switch try container.decode(PatchValueType.self, forKey: .type) {
        case .value:
            self = .value(try container.decode(AirshipJSON.self, forKey: .value))
        case .state:
            self = .state(scope: try container.decode([String].self, forKey: .scope))
        }
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .value(let value):
            try container.encode(PatchValueType.value, forKey: .type)
            try container.encode(value, forKey: .value)
        case .state(let scope):
            try container.encode(PatchValueType.state, forKey: .type)
            try container.encode(scope, forKey: .scope)
        }
    }

    /// Returns the patch's value, or nil when it is `null` or a `state` scope finds nothing.
    /// - Parameter state: The form's state.
    /// - Returns: The resolved value, or nil to leave the field as it was.
    func resolve(state: AirshipJSON) -> AirshipJSON? {
        let json: AirshipJSON?
        switch self {
        case .value(let value):
            json = value
        case .state(let scope):
            json = scope.reduce(state) { current, key in current?.object?[key] }
        }
        guard let json, !json.isNull else { return nil }
        return json
    }

    /// Returns the patch's value as a boolean, or nil when it resolves to nothing or to another
    /// type; nothing is coerced.
    /// - Parameter state: The form's state.
    /// - Returns: The resolved boolean, or nil to leave the field as it was.
    func resolveBool(state: AirshipJSON) -> Bool? {
        guard case .bool(let value) = resolve(state: state) else { return nil }
        return value
    }
}

/// The flattened fields of an email registration while patches apply, so a value set for one
/// `type` survives a patch that switches to another and back.
fileprivate struct EmailRegistrationDraft {
    var type: ThomasEmailRegistrationOption.EmailRegistrationType?
    var commercialOptedIn: Bool?
    var openTrackingOptedIn: Bool?
    var clickTrackingOptedIn: Bool?
    var properties: AirshipJSON?

    init(options: ThomasEmailRegistrationOption?) {
        switch options {
        case .doubleOptIn(let info):
            self.type = .doubleOptIn
            self.openTrackingOptedIn = info.openTrackingOptedIn
            self.clickTrackingOptedIn = info.clickTrackingOptedIn
            self.properties = info.properties
        case .commercial(let info):
            self.type = .commercial
            self.commercialOptedIn = info.optedIn
            self.openTrackingOptedIn = info.openTrackingOptedIn
            self.clickTrackingOptedIn = info.clickTrackingOptedIn
            self.properties = info.properties
        case .transactional(let info):
            self.type = .transactional
            self.openTrackingOptedIn = info.openTrackingOptedIn
            self.clickTrackingOptedIn = info.clickTrackingOptedIn
            self.properties = info.properties
        case .none:
            break
        }
    }

    mutating func apply(_ patch: ThomasEmailRegistrationPatch, state: AirshipJSON) {
        if let type = patch.type {
            self.type = type
        }

        if let value = patch.commercialOptedIn?.resolveBool(state: state) {
            self.commercialOptedIn = value
        }

        if let value = patch.openTrackingOptedIn?.resolveBool(state: state) {
            self.openTrackingOptedIn = value
        }

        if let value = patch.clickTrackingOptedIn?.resolveBool(state: state) {
            self.clickTrackingOptedIn = value
        }

        if let propertiesPatch = patch.properties {
            var object = self.properties?.object ?? [:]
            propertiesPatch.remove?.forEach { object[$0] = nil }
            propertiesPatch.set?.forEach { key, value in
                if let resolved = value.resolve(state: state) {
                    object[key] = resolved
                }
            }
            self.properties = .object(object)
        }
    }

    var options: ThomasEmailRegistrationOption? {
        switch type {
        case .doubleOptIn:
            .doubleOptIn(
                .init(
                    properties: properties,
                    openTrackingOptedIn: openTrackingOptedIn,
                    clickTrackingOptedIn: clickTrackingOptedIn
                )
            )
        case .commercial:
            .commercial(
                .init(
                    optedIn: commercialOptedIn ?? false,
                    properties: properties,
                    openTrackingOptedIn: openTrackingOptedIn,
                    clickTrackingOptedIn: clickTrackingOptedIn
                )
            )
        case .transactional:
            .transactional(
                .init(
                    properties: properties,
                    openTrackingOptedIn: openTrackingOptedIn,
                    clickTrackingOptedIn: clickTrackingOptedIn
                )
            )
        case .none:
            nil
        }
    }
}
