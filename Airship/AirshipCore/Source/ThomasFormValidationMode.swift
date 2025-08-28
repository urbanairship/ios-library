/* Copyright Airship and Contributors */



/// Represents the validation modes for a form.
enum ThomasFormValidationMode: ThomasSerializable {

    /// The form is validated only when a `ThomasButtonClickBehavior.formSubmit`
    /// or `ThomasButtonClickBehavior.formValidate` is triggered.
    case onDemand

    /// The form is validated immediately after any changes are made.
    case immediate

    private enum CodingKeys: String, CodingKey {
        case type
    }

    private enum ValidationType: String, Codable {
        case onDemand = "on_demand"
        case immediate
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type: ValidationType = try container.decode(ValidationType.self, forKey: .type)
        self = switch(type) {
        case .onDemand: .onDemand
        case .immediate: .immediate
        }
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch (self) {
        case .onDemand: try container.encode(ValidationType.onDemand, forKey: .type)
        case .immediate: try container.encode(ValidationType.immediate, forKey: .type)
        }
    }
}
