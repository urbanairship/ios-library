/* Copyright Airship and Contributors */



@MainActor
struct ThomasAssociatedLabelResolver: Sendable {
    var labelMap: [String: (ThomasState) -> String?] = [:]

    init(layout: AirshipLayout) {
        var labelMap: [String: (ThomasState) -> String?] = [:]
        let labels = layout.labels ?? []
        labels.forEach { info in
            if let labels = info.properties.labels, labels.type == .labels {
                labelMap[Self.makeKey(for: labels.viewID, viewType: labels.viewType)] = { state in
                    let resolvedString = info.resolveLabelString(thomasState: state)
                    return if info.properties.markdown?.disabled == true {
                        resolvedString
                    } else {
                        String(AttributedString(resolvedString).characters)
                    }
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
