import Foundation
@_spi(AirshipInternal) import AirshipBasement

struct ThomasStateTriggers: ThomasSerializable {
    var id: String
    var triggerWhenStateMatches: JSONPredicate
    var resetWhenStateMatches: JSONPredicate?
    var onTrigger: TriggerActions


    struct TriggerActions: ThomasSerializable {
        var stateActions: [ThomasStateAction]?
        /// If defined, `stateActions` will be ignored.
        var outcomes: [ThomasOutcome]?

        enum CodingKeys: String, CodingKey {
            case stateActions = "state_actions"
            case outcomes
        }
    }

    enum CodingKeys: String, CodingKey {
        case id = "identifier"
        case triggerWhenStateMatches = "trigger_when_state_matches"
        case resetWhenStateMatches = "reset_when_state_matches"
        case onTrigger = "on_trigger"
    }
}
