/* Copyright Airship and Contributors */

import Foundation

/// Unified outcome system for Thomas views.
/// Outcomes are the single source of truth for "what happens when something is triggered."
/// When `outcomes` is present on any schema type it takes priority over legacy fields
/// (`behaviors`, `state_actions`, `actions`).
enum ThomasOutcome: ThomasSerializable {
    case airshipAction(AirshipActionOutcome)
    case dismiss(DismissOutcome)
    case pagerPlayback(PagerPlaybackOutcome)
    case pagerJumpNavigation(PagerJumpNavigationOutcome)
    case pagerStepNavigation(PagerStepNavigationOutcome)
    case mediaPlayback(MediaPlaybackOutcome)
    case mediaAudio(MediaAudioOutcome)
    case stateAction(StateActionOutcome)
    case form(FormOutcome)
    case asyncView(AsyncViewOutcome)

    enum OutcomeType: String, Codable, Sendable {
        case airshipAction = "airship_action"
        case dismiss = "dismiss"
        case pagerPlayback = "pager_playback"
        case pagerJumpNavigation = "pager_jump_navigation"
        case pagerStepNavigation = "pager_step_navigation"
        case mediaPlayback = "media_playback"
        case mediaAudio = "media_audio"
        case stateAction = "state_action"
        case form = "form"
        case asyncView = "async_view"
    }

    private enum CodingKeys: String, CodingKey {
        case type
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(OutcomeType.self, forKey: .type)
        
        self = switch type {
        case .airshipAction: .airshipAction(try AirshipActionOutcome(from: decoder))
        case .dismiss: .dismiss(try DismissOutcome(from: decoder))
        case .pagerPlayback: .pagerPlayback(try PagerPlaybackOutcome(from: decoder))
        case .pagerJumpNavigation: .pagerJumpNavigation(try PagerJumpNavigationOutcome(from: decoder))
        case .pagerStepNavigation: .pagerStepNavigation(try PagerStepNavigationOutcome(from: decoder))
        case .mediaPlayback: .mediaPlayback(try MediaPlaybackOutcome(from: decoder))
        case .mediaAudio: .mediaAudio(try MediaAudioOutcome(from: decoder))
        case .stateAction: .stateAction(try StateActionOutcome(from: decoder))
        case .form: .form(try FormOutcome(from: decoder))
        case .asyncView: .asyncView(try AsyncViewOutcome(from: decoder))
        }
    }

    func encode(to encoder: any Encoder) throws {
        switch self {
        case .airshipAction(let outcome): try outcome.encode(to: encoder)
        case .dismiss(let outcome): try outcome.encode(to: encoder)
        case .pagerPlayback(let outcome): try outcome.encode(to: encoder)
        case .pagerJumpNavigation(let outcome): try outcome.encode(to: encoder)
        case .pagerStepNavigation(let outcome): try outcome.encode(to: encoder)
        case .mediaPlayback(let outcome): try outcome.encode(to: encoder)
        case .mediaAudio(let outcome): try outcome.encode(to: encoder)
        case .stateAction(let outcome): try outcome.encode(to: encoder)
        case .form(let outcome): try outcome.encode(to: encoder)
        case .asyncView(let outcome): try outcome.encode(to: encoder)
        }
    }

    // MARK: - Outcome types

    struct AirshipActionOutcome: ThomasSerializable {
        let type: OutcomeType = .airshipAction
        let actions: ThomasActionsPayload
        let identifier: String

        enum CodingKeys: String, CodingKey {
            case type, actions, identifier
        }
    }

    struct DismissOutcome: ThomasSerializable {
        let type: OutcomeType = .dismiss
        /// When `true`, cancels future displays. Defaults to `false`.
        let cancel: Bool?
        let identifier: String

        enum CodingKeys: String, CodingKey {
            case type, cancel, identifier
        }
    }

    struct PagerPlaybackOutcome: ThomasSerializable {
        let type: OutcomeType = .pagerPlayback
        let command: Command
        let identifier: String

        enum Command: String, ThomasSerializable {
            case pause, resume, toggle
        }

        enum CodingKeys: String, CodingKey {
            case type, command, identifier
        }
    }

    struct PagerJumpNavigationOutcome: ThomasSerializable {
        let type: OutcomeType = .pagerJumpNavigation
        let page: Page
        let identifier: String

        enum Page: String, ThomasSerializable {
            case start, end
        }

        enum CodingKeys: String, CodingKey {
            case type, page, identifier
        }
    }

    struct PagerStepNavigationOutcome: ThomasSerializable {
        let type: OutcomeType = .pagerStepNavigation
        let direction: Direction
        /// Behavior when navigation is requested at a boundary.
        /// - `ignore`: Do nothing (default)
        /// - `dismiss`: Dismiss the view
        /// - `wrap`: Wrap to the other end
        let boundaryBehavior: BoundaryBehavior
        let identifier: String

        enum Direction: String, ThomasSerializable {
            case next, previous
        }

        enum BoundaryBehavior: String, ThomasSerializable {
            case wrap, dismiss, ignore
        }

        enum CodingKeys: String, CodingKey {
            case type
            case direction
            case boundaryBehavior = "boundary_behavior"
            case identifier
        }
        
        init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.direction = try container.decode(Direction.self, forKey: .direction)
            self.boundaryBehavior = try container.decodeIfPresent(BoundaryBehavior.self, forKey: .boundaryBehavior) ?? .ignore
            self.identifier = try container.decode(String.self, forKey: .identifier)
        }
        
        init(direction: Direction, boundaryBehavior: BoundaryBehavior = .ignore, identifier: String) {
            self.direction = direction
            self.boundaryBehavior = boundaryBehavior
            self.identifier = identifier
        }
    }

    struct MediaPlaybackOutcome: ThomasSerializable {
        let type: OutcomeType = .mediaPlayback
        let command: Command
        let identifier: String

        enum Command: String, ThomasSerializable {
            case play, pause, toggle
        }

        enum CodingKeys: String, CodingKey {
            case type, command, identifier
        }
    }

    struct MediaAudioOutcome: ThomasSerializable {
        let type: OutcomeType = .mediaAudio
        let command: Command
        let identifier: String

        enum Command: String, ThomasSerializable {
            case mute, unmute, toggle
        }

        enum CodingKeys: String, CodingKey {
            case type, command, identifier
        }
    }

    struct StateActionOutcome: ThomasSerializable {
        let type: OutcomeType = .stateAction
        let action: ThomasStateAction
        let identifier: String

        enum CodingKeys: String, CodingKey {
            case type, action, identifier
        }
    }

    struct FormOutcome: ThomasSerializable {
        let type: OutcomeType = .form
        let command: Command
        let identifier: String

        enum Command: String, ThomasSerializable {
            case validate, submit
        }

        enum CodingKeys: String, CodingKey {
            case type, command, identifier
        }
    }
    
    struct AsyncViewOutcome: ThomasSerializable {
        let type: OutcomeType = .asyncView
        let command: Command
        let identifier: String
        
        enum Command: String, ThomasSerializable {
            case retry
        }
        
        enum CodingKeys: String, CodingKey {
            case type, command, identifier
        }
    }
}
