/* Copyright Airship and Contributors */

import Foundation
public import AirshipBasement

/// A single layout-authored context item for an inference request. Renderer-side mirror
/// of the AI framework's context item, kept Core-free so it can live in the renderer.
/// - Note: For internal use only. :nodoc:
@_spi(AirshipInternal)
public struct ThomasAIContextItem: Sendable {
    /// Self-describing text inserted into the prompt as-is.
    public let content: String

    /// Drop-ordering priority, where **lower is more important** (negatives allowed,
    /// ranking above the `0` default). Items with the highest value are dropped first
    /// when the model trims context to fit its input budget.
    public let priority: Double

    public init(content: String, priority: Double = 0.0) {
        self.content = content
        self.priority = priority
    }
}

/// A single on-device inference request over user-typed text.
/// - Note: For internal use only. :nodoc:
@_spi(AirshipInternal)
public struct ThomasAIInferenceRequest: Sendable {
    /// Layout-authored instruction describing what to derive from the text.
    public let prompt: String

    /// The user's current text.
    public let text: String

    /// Expected output shape.
    public let outputSchema: AirshipJSONSchema

    /// Layout-authored context appended after the app's provider context.
    public let additionalContext: [ThomasAIContextItem]

    /// Layout-authored hints carried on the subject handed to the app's context provider
    /// (as `subject.hints`).
    public let subjectHints: [String: String]

    public init(
        prompt: String,
        text: String,
        outputSchema: AirshipJSONSchema,
        additionalContext: [ThomasAIContextItem] = [],
        subjectHints: [String: String] = [:]
    ) {
        self.prompt = prompt
        self.text = text
        self.outputSchema = outputSchema
        self.additionalContext = additionalContext
        self.subjectHints = subjectHints
    }
}

/// Per-usage availability snapshot streamed from a `SceneAIExecutor`. Thomas bridges
/// this struct into layout state so predicates and pager branching can gate on specific
/// usages (e.g. `$ai.current.available`).
/// - Note: For internal use only. :nodoc:
@_spi(AirshipInternal)
public struct SceneAIStatus: Sendable, Encodable {
    /// Whether the text-input inference model can run right now.
    public var textInputInference: Bool

    public init(textInputInference: Bool = false) {
        self.textInputInference = textInputInference
    }

    enum CodingKeys: String, CodingKey {
        case textInputInference = "text_input_inference"
    }
}

/// Runs on-device AI inference for layout text inputs. The renderer is Core-free, so the
/// host supplies an implementation through `ThomasExtensions` (AirshipScenes wires one
/// backed by the SDK's AI manager).
/// - Note: For internal use only. :nodoc:
@_spi(AirshipInternal)
public protocol SceneAIExecutor: Sendable {

    /// Whether the on-device model can run right now. Callers check this before
    /// scheduling work so an absent model never delays the form — fail open, non-blocking.
    @MainActor
    var isAvailable: Bool { get }

    /// A stream of per-usage availability changes, starting with the current values and
    /// emitting on any change. Thomas bridges this struct into layout state so predicates
    /// and pager branching can gate on specific usages.
    @MainActor
    var statusUpdates: AsyncStream<SceneAIStatus> { get }

    /// Runs inference over the user's text. Returns the model's structured output, or
    /// nil when the model is unavailable or the evaluation failed — callers fail open.
    func run(request: ThomasAIInferenceRequest) async -> AirshipJSON?
}

/// The `ai_inference` payload reported on a form child (`{ result, output }`). Carried on the
/// text value so it survives form folding/nesting and reaches the event payload; serialized
/// through its own Codable rather than hand-built JSON.
///
/// Reporting is opt-in at every level: a value appears in `output` only when its schema node
/// AND every ancestor container node carry the `x-ua-report-property` extension. An unflagged
/// node prunes itself and its entire subtree — so an unflagged object omits even its flagged
/// children, and a flagged child under an unflagged parent is not reported. The root output
/// node must be flagged too, or nothing is reported. The pruning happens when a `.success`
/// report is constructed. `output` is modeled as part of `.success` only, so a failed report
/// can't carry one. Encodes to the flat wire shape `{ result, output? }`.
enum ThomasAIInferenceReport: Codable, Sendable, Equatable {
    /// A completed inference with the reportable output subset (nil when nothing is opted in).
    case success(output: AirshipJSON?)

    /// A failed or unavailable inference.
    case failed

    /// Schema extension keyword opting a property into reporting.
    static let reportPropertyKey: String = "x-ua-report-property"

    /// A completed inference. `output` is pruned to the reportable subset (values on a
    /// fully-flagged schema path); a nil schema or nothing flagged yields no output.
    init(output: AirshipJSON, schema: AirshipJSONSchema?) {
        self = .success(output: schema.flatMap { Self.reportedOutput(output, schema: $0) })
    }

    private enum Status: String, Codable {
        case success
        case failed
    }

    private enum CodingKeys: String, CodingKey {
        case result
        case output
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .success(let output):
            try container.encode(Status.success, forKey: .result)
            try container.encodeIfPresent(output, forKey: .output)
        case .failed:
            try container.encode(Status.failed, forKey: .result)
        }
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        switch try container.decode(Status.self, forKey: .result) {
        case .success:
            self = .success(output: try container.decodeIfPresent(AirshipJSON.self, forKey: .output))
        case .failed:
            self = .failed
        }
    }

    /// Recursively keeps only the values reachable through an unbroken chain of flagged
    /// nodes. Returns nil when nothing under `schema` is reportable.
    static func reportedOutput(_ value: AirshipJSON, schema: AirshipJSONSchema) -> AirshipJSON? {
        // Every node on the path must opt in: an unflagged node prunes itself and its whole
        // subtree, so a value is reported only when it and all its ancestors are flagged.
        guard schema.isReportProperty else { return nil }

        switch schema.type {
        case .object(let info):
            guard let object = value.object, let properties = info.properties else { return nil }
            var kept: [String: AirshipJSON] = [:]
            for (name, propertySchema) in properties {
                if let child = object[name],
                   let filtered = reportedOutput(child, schema: propertySchema) {
                    kept[name] = filtered
                }
            }
            return kept.isEmpty ? nil : .object(kept)
        case .array(let info):
            guard let array = value.array else { return nil }
            let kept = array.compactMap { reportedOutput($0, schema: info.items) }
            return kept.isEmpty ? nil : .array(kept)
        case .string, .boolean, .integer, .number:
            return value
        @unknown default:
            // A value type from a newer Basement — fail closed: don't report what we
            // can't reason about.
            return nil
        }
    }
}

extension AirshipJSONSchema {
    /// Whether this node opts its value into reporting (`x-ua-report-property: true`).
    var isReportProperty: Bool {
        extensions[ThomasAIInferenceReport.reportPropertyKey]?.bool ?? false
    }
}
