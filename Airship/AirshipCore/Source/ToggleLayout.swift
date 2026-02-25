
import Foundation
import SwiftUI

@MainActor
struct ToggleLayout<Content> : View  where Content : View {
    @EnvironmentObject private var thomasState: ThomasState

    @Binding private var isOn: Bool
    private let onToggleOn: ThomasViewInfo.ToggleActions
    private let onToggleOff: ThomasViewInfo.ToggleActions
    private let content: () -> Content

    init(
        isOn: Binding<Bool>,
        onToggleOn: ThomasViewInfo.ToggleActions,
        onToggleOff: ThomasViewInfo.ToggleActions,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self._isOn = isOn
        self.onToggleOn = onToggleOn
        self.onToggleOff = onToggleOff
        self.content = content
    }

    var body: some View {
        Toggle(isOn: $isOn.animation()) {
            content().background(Color.airshipTappableClear)
        }
        .airshipOnChangeOf(self.isOn) { isOn in
            self.handleStateActions(isOn)
        }
        .toggleStyle(PlainButtonToggleStyle())
        .accessibilityRemoveTraits(.isSelected)
    }

    private func handleStateActions(_ isOn: Bool) {
        let actions: ThomasViewInfo.ToggleActions = isOn ? onToggleOn : onToggleOff
        guard let stateActions = actions.stateActions else { return }
        thomasState.processStateActions(stateActions)
    }
}

fileprivate struct PlainButtonToggleStyle: ToggleStyle {
    func makeBody(configuration: Self.Configuration) -> some View {
        Button {
            configuration.isOn.toggle()
        }
        label: {
            configuration.label
        }
#if os(tvOS)
        .buttonStyle(TVButtonStyle())
#else
        .buttonStyle(.plain)
#endif
    }
}

