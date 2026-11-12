/* Copyright Airship and Contributors */

import Foundation

@MainActor
struct ThomasAssociatedLabelResolver: Sendable {
    private var labelMap: [String: (ThomasState) -> String?] = [:]

    init(layout: AirshipLayout, localizer: any ThomasLocalizer) {
        var labelMap: [String: (ThomasState) -> String?] = [:]
        let labels = layout.labels ?? []
        labels.forEach { info in
            if let labels = info.properties.labels, labels.type == .labels {
                labelMap[Self.makeKey(for: labels.viewID, viewType: labels.viewType)] = { state in
                    Self.plainText(of: info, state: state, localizer: localizer)
                }
            }
        }

        self.labelMap = labelMap
    }

    func labelFor(
        identifier: String?,
        viewType: ThomasViewInfo.ViewType,
        thomasState: ThomasState
    ) -> String? {
        guard let identifier else {
            return nil
        }
        return labelMap[Self.makeKey(for: identifier, viewType: viewType)]?(thomasState)
    }

    func merging(viewInfo: ThomasViewInfo, localizer: any ThomasLocalizer) -> ThomasAssociatedLabelResolver {
        var merged = self
        viewInfo.extractDescendants { info -> ThomasViewInfo.Label? in
            if case let .label(label) = info { label } else { nil }
        }.forEach { info in
            if let labels = info.properties.labels, labels.type == .labels {
                merged.labelMap[Self.makeKey(for: labels.viewID, viewType: labels.viewType)] = { state in
                    Self.plainText(of: info, state: state, localizer: localizer)
                }
            }
        }
        return merged
    }

    /// The label's text with any markdown removed, as VoiceOver should read it.
    private static func plainText(
        of info: ThomasViewInfo.Label,
        state: ThomasState,
        localizer: any ThomasLocalizer
    ) -> String {
        let resolvedString = info.resolveLabelString(thomasState: state, localizer: localizer)
        guard
            info.properties.markdown?.disabled != true,
            let attributed = try? AttributedString(
                markdown: resolvedString,
                options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)
            )
        else {
            return resolvedString
        }
        return String(attributed.characters)
    }

    private static func makeKey(for identifier: String, viewType: ThomasViewInfo.ViewType) -> String {
        return "\(identifier):\(viewType.rawValue)"
    }
}

fileprivate extension AirshipLayout {
    var labels: [ThomasViewInfo.Label]? {
        return extract { info in
            return if case let .label(label) = info {
                label
            } else {
                nil
            }
        }
    }
}
